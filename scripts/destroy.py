import argparse
import json
import os
import secrets
import string
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

DEFAULTS = {
    "location": "eastus2",
    "storage_account_name_prefix": "stadvworks",
    "account_replication_type": "LRS",
    "account_tier": "Standard",
    "public_network_access_enabled": True,
    "is_hns_enabled": True,
    "data_factory_name_prefix": "adf-adventureworks",
    "http_linked_service_name_prefix": "ls-http-adventureworks",
    "http_base_url": "https://raw.githubusercontent.com",
    "http_authentication_type": "Anonymous",
    "http_enable_certificate_validation": True,
    "adls_linked_service_name_prefix": "ls-adls-adventureworks",
    "linked_services_description": "Linked services for HTTP source and ADLS Gen2 sink",
    "pipeline_name_prefix": "pl-adventureworks-http",
    "http_dataset_name_prefix": "ds_http_adventureworks",
    "parameters_dataset_name_prefix": "ds_parameters_adventureworks",
    "sink_dataset_name_prefix": "ds_adls_bronze_adventureworks",
    "parameters_container": "parameters",
    "parameters_path": "",
    "parameters_file": "parameters.json",
    "sink_file_system": "bronze",
    "databricks_workspace_name_prefix": "dbw-adventureworks",
    "databricks_managed_rg_name_prefix": "rg-databricks-adventureworks",
    "databricks_sku": "premium",
    "databricks_access_connector_name_prefix": "dac-adventureworks",
    "databricks_access_role_definition_name": "Storage Blob Data Contributor",
    "adls_oauth_application_name_prefix": "sp-adventureworks-adls",
    "adls_oauth_container_names": ["bronze", "silver", "gold", "parameters"],
    "adls_oauth_role_definition_name": "Storage Blob Data Contributor",
    "adls_oauth_secret_end_date_relative": "2160h",
    "databricks_cluster_name_prefix": "dbc-adventureworks",
    "databricks_spark_version": "16.4.x-scala2.13",
    "databricks_node_type_id": "Standard_D4pds_v6",
    "databricks_autotermination_minutes": 30,
    "databricks_runtime_engine": "PHOTON",
    "databricks_data_security_mode": "DATA_SECURITY_MODE_AUTO",
    "databricks_cluster_kind": "CLASSIC_PREVIEW",
    "databricks_is_single_node": True,
    "databricks_num_workers": 2,
    "synapse_workspace_name_prefix": "synapse-adventureworks",
    "synapse_managed_rg_name_prefix": "rg-synapse-adventureworks",
    "synapse_storage_account_name_prefix": "stsynapse",
    "synapse_filesystem_name": "synapse",
    "synapse_sql_admin_login": "synapseadmin",
    "synapse_storage_role_definition_name": "Storage Blob Data Contributor",
}


def run(cmd):
    print("\n$ " + " ".join(cmd))
    subprocess.check_call(cmd)


def run_capture(cmd):
    print("\n$ " + " ".join(cmd))
    return subprocess.check_output(cmd, text=True).strip()


def run_capture_optional(cmd):
    try:
        return run_capture(cmd)
    except subprocess.CalledProcessError:
        return None


def resolve_aad_group_object_id(group_name):
    """
    Resolve an Entra ID group object ID using Azure CLI.

    Notes:
    - This uses `az ad group show`, which may require directory read permissions in your tenant.
    - On Windows, `uv run` often cannot resolve `az` from PATH; prefer `az.cmd`.
    - If directory reads are restricted, you'll need to supply the object ID via env var or tfvars.
    """
    if not group_name:
        return None

    az_exe = "az.cmd" if os.name == "nt" else "az"

    # `--group` accepts display name or object id; we pass the name and request `id`.
    return run_capture_optional(
        [az_exe, "ad", "group", "show", "--group", group_name, "--query", "id", "-o", "tsv"]
    )


def resolve_signed_in_user():
    az_exe = "az.cmd" if os.name == "nt" else "az"
    user_login = run_capture_optional([
        az_exe,
        "account", "show",
        "--query", "user.name",
        "-o", "tsv",
    ])
    user_object_id = run_capture_optional([
        az_exe,
        "ad", "signed-in-user", "show",
        "--query", "id",
        "-o", "tsv",
    ])
    return user_login or None, user_object_id or None


def hcl_value(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (list, tuple)):
        rendered = ", ".join(hcl_value(item) for item in value)
        return f"[{rendered}]"
    escaped = str(value).replace("\"", "\\\"")
    return f"\"{escaped}\""


def write_tfvars(path, items):
    lines = [f"{key} = {hcl_value(value)}" for key, value in items]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def load_env_file(path):
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        key = key.strip()
        value = value.strip()
        if key and key not in os.environ:
            os.environ[key] = value


def read_tfvars_value(path, key):
    if not path.exists():
        return None
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" not in stripped:
            continue
        current_key, value = stripped.split("=", 1)
        if current_key.strip() != key:
            continue
        value = value.strip()
        if value == "null":
            return None
        if value.startswith("\"") and value.endswith("\""):
            return value[1:-1].replace("\\\"", "\"")
        return value
    return None


def generate_password(length=20):
    if length < 12:
        length = 12
    alphabet = string.ascii_letters + string.digits + "!@#$%_-+="
    while True:
        password = "".join(secrets.choice(alphabet) for _ in range(length))
        if (
            any(c.islower() for c in password)
            and any(c.isupper() for c in password)
            and any(c.isdigit() for c in password)
            and any(c in "!@#$%_-+=" for c in password)
        ):
            return password


def read_tfstate(path):
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def read_tfstate_with_backup(tf_dir):
    state = read_tfstate(tf_dir / "terraform.tfstate")
    if state:
        return state
    return read_tfstate(tf_dir / "terraform.tfstate.backup")


def state_has_resources(tf_dir):
    state = read_tfstate_with_backup(tf_dir)
    if not state:
        return False
    return bool(state.get("resources"))


def get_tfstate_output(tf_dir, output_name):
    state = read_tfstate_with_backup(tf_dir)
    if not state:
        return None
    output = state.get("outputs", {}).get(output_name)
    if isinstance(output, dict):
        return output.get("value")
    return None


def get_rg_name_from_state(rg_dir):
    state = read_tfstate_with_backup(rg_dir)
    if not state:
        return None
    for resource in state.get("resources", []):
        if resource.get("type") != "azurerm_resource_group":
            continue
        for instance in resource.get("instances", []):
            name = instance.get("attributes", {}).get("name")
            if name:
                return name
    return None


def get_storage_account_id_from_state(storage_dir):
    state = read_tfstate_with_backup(storage_dir)
    if not state:
        return None
    for resource in state.get("resources", []):
        if resource.get("type") != "azurerm_storage_account":
            continue
        for instance in resource.get("instances", []):
            storage_id = instance.get("attributes", {}).get("id")
            if storage_id:
                return storage_id
    return None


def get_storage_account_id(storage_dir):
    return (
        get_output_optional(storage_dir, "storage_account_id")
        or get_tfstate_output(storage_dir, "storage_account_id")
        or get_storage_account_id_from_state(storage_dir)
    )


def get_databricks_host_from_cluster_state(cluster_dir):
    state = read_tfstate_with_backup(cluster_dir)
    if not state:
        return None
    for resource in state.get("resources", []):
        if resource.get("type") != "databricks_cluster":
            continue
        for instance in resource.get("instances", []):
            url = instance.get("attributes", {}).get("url")
            if not url:
                continue
            parsed = urlparse(url)
            if parsed.scheme and parsed.netloc:
                return f"{parsed.scheme}://{parsed.netloc}"
            return url.split("#", 1)[0].rstrip("/")
    return None


def get_output_optional(tf_dir, output_name):
    try:
        return run_capture(
            ["terraform", f"-chdir={tf_dir}", "-no-color", "output", "-raw", output_name]
        )
    except subprocess.CalledProcessError:
        return None


def get_rg_name(rg_dir):
    return (
        get_output_optional(rg_dir, "resource_group_name")
        or get_tfstate_output(rg_dir, "resource_group_name")
        or get_rg_name_from_state(rg_dir)
        or read_tfvars_value(rg_dir / "terraform.tfvars", "resource_group_name")
    )


def write_storage_tfvars(storage_dir, rg_name):
    storage_blob_contributor_object_id = os.environ.get("STORAGE_BLOB_CONTRIBUTOR_OBJECT_ID")
    if not storage_blob_contributor_object_id:
        _, user_object_id = resolve_signed_in_user()
        storage_blob_contributor_object_id = user_object_id
    items = [
        ("resource_group_name", rg_name),
        ("location", DEFAULTS["location"]),
        ("storage_account_name_prefix", DEFAULTS["storage_account_name_prefix"]),
        ("account_replication_type", DEFAULTS["account_replication_type"]),
        ("account_tier", DEFAULTS["account_tier"]),
        ("public_network_access_enabled", DEFAULTS["public_network_access_enabled"]),
        ("is_hns_enabled", DEFAULTS["is_hns_enabled"]),
    ]
    if storage_blob_contributor_object_id:
        items.append(("storage_blob_contributor_object_id", storage_blob_contributor_object_id))
    write_tfvars(storage_dir / "terraform.tfvars", items)


def write_data_factory_tfvars(data_factory_dir, rg_name):
    items = [
        ("resource_group_name", rg_name),
        ("location", DEFAULTS["location"]),
        ("data_factory_name_prefix", DEFAULTS["data_factory_name_prefix"]),
    ]
    write_tfvars(data_factory_dir / "terraform.tfvars", items)


def write_adf_linked_services_tfvars(linked_services_dir, data_factory_dir, storage_dir):
    data_factory_id = (
        get_output_optional(data_factory_dir, "data_factory_id")
        or get_tfstate_output(data_factory_dir, "data_factory_id")
    )
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for linked services destroy.")
    storage_dfs_endpoint = (
        get_output_optional(storage_dir, "primary_dfs_endpoint")
        or get_tfstate_output(storage_dir, "primary_dfs_endpoint")
    )
    storage_account_key = (
        get_output_optional(storage_dir, "storage_account_primary_access_key")
        or get_tfstate_output(storage_dir, "storage_account_primary_access_key")
    )
    if not storage_dfs_endpoint or not storage_account_key:
        raise RuntimeError("Storage outputs not found for linked services destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("http_linked_service_name_prefix", DEFAULTS["http_linked_service_name_prefix"]),
        ("http_base_url", DEFAULTS["http_base_url"]),
        ("http_authentication_type", DEFAULTS["http_authentication_type"]),
        ("http_enable_certificate_validation", DEFAULTS["http_enable_certificate_validation"]),
        ("adls_linked_service_name_prefix", DEFAULTS["adls_linked_service_name_prefix"]),
        ("storage_dfs_endpoint", storage_dfs_endpoint),
        ("storage_account_key", storage_account_key),
        ("description", DEFAULTS["linked_services_description"]),
    ]
    write_tfvars(linked_services_dir / "terraform.tfvars", items)


def write_adf_pipeline_tfvars(pipeline_dir, data_factory_dir, linked_services_dir):
    data_factory_id = (
        get_output_optional(data_factory_dir, "data_factory_id")
        or get_tfstate_output(data_factory_dir, "data_factory_id")
    )
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for pipeline destroy.")
    http_linked_service_name = (
        get_output_optional(linked_services_dir, "http_linked_service_name")
        or get_tfstate_output(linked_services_dir, "http_linked_service_name")
    )
    adls_linked_service_name = (
        get_output_optional(linked_services_dir, "adls_linked_service_name")
        or get_tfstate_output(linked_services_dir, "adls_linked_service_name")
    )
    if not http_linked_service_name or not adls_linked_service_name:
        raise RuntimeError("Linked service outputs not found for pipeline destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("http_linked_service_name", http_linked_service_name),
        ("adls_linked_service_name", adls_linked_service_name),
        ("pipeline_name_prefix", DEFAULTS["pipeline_name_prefix"]),
        ("http_dataset_name_prefix", DEFAULTS["http_dataset_name_prefix"]),
        ("parameters_dataset_name_prefix", DEFAULTS["parameters_dataset_name_prefix"]),
        ("sink_dataset_name_prefix", DEFAULTS["sink_dataset_name_prefix"]),
        ("parameters_container", DEFAULTS["parameters_container"]),
        ("parameters_path", DEFAULTS["parameters_path"]),
        ("parameters_file", DEFAULTS["parameters_file"]),
        ("sink_file_system", DEFAULTS["sink_file_system"]),
    ]
    write_tfvars(pipeline_dir / "terraform.tfvars", items)


def write_databricks_tfvars(databricks_dir, rg_name):
    items = [
        ("resource_group_name", rg_name),
        ("location", DEFAULTS["location"]),
        ("workspace_name_prefix", DEFAULTS["databricks_workspace_name_prefix"]),
        ("managed_resource_group_name_prefix", DEFAULTS["databricks_managed_rg_name_prefix"]),
        ("sku", DEFAULTS["databricks_sku"]),
    ]
    write_tfvars(databricks_dir / "terraform.tfvars", items)


def write_databricks_access_tfvars(access_dir, rg_name, storage_account_id):
    items = [
        ("resource_group_name", rg_name),
        ("location", DEFAULTS["location"]),
        ("storage_account_id", storage_account_id),
        ("access_connector_name_prefix", DEFAULTS["databricks_access_connector_name_prefix"]),
        ("role_definition_name", DEFAULTS["databricks_access_role_definition_name"]),
    ]
    write_tfvars(access_dir / "terraform.tfvars", items)


def write_adls_oauth_tfvars(adls_oauth_dir, rg_name, storage_account_id):
    """
    Write terraform.tfvars for the ADLS OAuth (service principal) stack.

    This fixes the NameError you hit during destroy: write_adls_oauth_tfvars was being called
    but not defined.
    """
    items = [
        ("resource_group_name", rg_name),
        ("location", DEFAULTS["location"]),
        ("storage_account_id", storage_account_id),
        ("application_name_prefix", DEFAULTS["adls_oauth_application_name_prefix"]),
        ("container_names", DEFAULTS["adls_oauth_container_names"]),
        ("role_definition_name", DEFAULTS["adls_oauth_role_definition_name"]),
        ("secret_end_date_relative", DEFAULTS["adls_oauth_secret_end_date_relative"]),
    ]
    write_tfvars(adls_oauth_dir / "terraform.tfvars", items)


def normalize_databricks_host(value):
    if not value:
        return None
    stripped = str(value).strip().strip("\"")
    parsed = urlparse(stripped)
    if parsed.scheme and parsed.netloc:
        host = f"{parsed.scheme}://{parsed.netloc}"
    else:
        host = stripped
        if not (host.startswith("http://") or host.startswith("https://")):
            host = f"https://{host}"
    host = host.rstrip("/")
    if host in ("http://", "https://"):
        return None
    if any(ord(ch) < 32 for ch in host):
        return None
    return host


def write_databricks_cluster_tfvars(databricks_cluster_dir, databricks_dir):
    databricks_host = (
        get_output_optional(databricks_dir, "databricks_workspace_url")
        or get_tfstate_output(databricks_dir, "databricks_workspace_url")
    )
    if not databricks_host:
        databricks_host = read_tfvars_value(databricks_cluster_dir / "terraform.tfvars", "databricks_host")
    databricks_host = normalize_databricks_host(databricks_host) or get_databricks_host_from_cluster_state(
        databricks_cluster_dir
    )
    if not databricks_host:
        raise RuntimeError("Databricks workspace URL not found for cluster destroy.")
    databricks_token = os.environ.get("DATABRICKS_TOKEN")
    items = [
        ("databricks_host", databricks_host),
        ("cluster_name_prefix", DEFAULTS["databricks_cluster_name_prefix"]),
        ("spark_version", DEFAULTS["databricks_spark_version"]),
        ("node_type_id", DEFAULTS["databricks_node_type_id"]),
        ("autotermination_minutes", DEFAULTS["databricks_autotermination_minutes"]),
        ("runtime_engine", DEFAULTS["databricks_runtime_engine"]),
        ("data_security_mode", DEFAULTS["databricks_data_security_mode"]),
        ("cluster_kind", DEFAULTS["databricks_cluster_kind"]),
        ("is_single_node", DEFAULTS["databricks_is_single_node"]),
        ("num_workers", DEFAULTS["databricks_num_workers"]),
    ]
    if databricks_token:
        items.append(("databricks_token", databricks_token))
    write_tfvars(databricks_cluster_dir / "terraform.tfvars", items)


def write_databricks_notebooks_tfvars(databricks_notebooks_dir, databricks_dir, databricks_cluster_dir):
    databricks_host = (
        get_output_optional(databricks_dir, "databricks_workspace_url")
        or get_tfstate_output(databricks_dir, "databricks_workspace_url")
    )
    if not databricks_host:
        databricks_host = read_tfvars_value(databricks_cluster_dir / "terraform.tfvars", "databricks_host")
    databricks_host = normalize_databricks_host(databricks_host) or get_databricks_host_from_cluster_state(
        databricks_cluster_dir
    )
    if not databricks_host:
        raise RuntimeError("Databricks workspace URL not found for notebooks destroy.")
    databricks_token = os.environ.get("DATABRICKS_TOKEN")
    items = [
        ("databricks_host", databricks_host),
    ]
    if databricks_token:
        items.append(("databricks_token", databricks_token))
    write_tfvars(databricks_notebooks_dir / "terraform.tfvars", items)


def write_synapse_tfvars(synapse_dir, rg_name, shared_storage_account_id=None):
    tfvars_path = synapse_dir / "terraform.tfvars"
    sql_admin_login = (
        os.environ.get("SYNAPSE_SQL_ADMIN_LOGIN")
        or read_tfvars_value(tfvars_path, "sql_admin_login")
        or DEFAULTS["synapse_sql_admin_login"]
    )
    sql_admin_password = os.environ.get("SYNAPSE_SQL_ADMIN_PASSWORD") or read_tfvars_value(
        tfvars_path, "sql_admin_password"
    )
    if sql_admin_password and sql_admin_password.strip().lower().startswith("changeme"):
        sql_admin_password = None
    aad_admin_login = os.environ.get("SYNAPSE_AAD_ADMIN_LOGIN")
    aad_admin_object_id = os.environ.get("SYNAPSE_AAD_ADMIN_OBJECT_ID")
    filesystem_name = (
        os.environ.get("SYNAPSE_FILESYSTEM_NAME")
        or read_tfvars_value(tfvars_path, "filesystem_name")
        or DEFAULTS["synapse_filesystem_name"]
    )

    if not sql_admin_password:
        sql_admin_password = generate_password()
        print("Generated placeholder Synapse SQL admin password for destroy.")

    if not aad_admin_login:
        aad_admin_login = read_tfvars_value(tfvars_path, "aad_admin_login")
    if not aad_admin_object_id:
        aad_admin_object_id = read_tfvars_value(tfvars_path, "aad_admin_object_id")
    if aad_admin_login and not aad_admin_object_id:
        resolved_object_id = resolve_aad_group_object_id(aad_admin_login)
        if resolved_object_id:
            aad_admin_object_id = resolved_object_id
        else:
            user_login, user_object_id = resolve_signed_in_user()
            if user_login and user_object_id and user_login.lower() == aad_admin_login.lower():
                aad_admin_object_id = user_object_id
    if not aad_admin_login and not aad_admin_object_id:
        user_login, user_object_id = resolve_signed_in_user()
        if user_login:
            aad_admin_login = user_login
        if user_object_id:
            aad_admin_object_id = user_object_id

    example_path = synapse_dir / "terraform.tfvars.example"
    if example_path.exists() and not aad_admin_login:
        aad_admin_login = read_tfvars_value(example_path, "aad_admin_login")
        if aad_admin_login and not aad_admin_object_id:
            resolved_object_id = resolve_aad_group_object_id(aad_admin_login)
            if resolved_object_id:
                aad_admin_object_id = resolved_object_id
    if not aad_admin_login or not aad_admin_object_id:
        raise RuntimeError(
            "Missing Synapse Entra admin info. "
            "Set SYNAPSE_AAD_ADMIN_LOGIN (group recommended). "
            "If you can't resolve the group object id with `az ad group show --group <name>`, "
            "set SYNAPSE_AAD_ADMIN_OBJECT_ID or add `aad_admin_object_id` to terraform/11_synapse_analytics/terraform.tfvars."
        )

    items = [
        ("resource_group_name", rg_name),
        ("location", DEFAULTS["location"]),
        ("workspace_name_prefix", DEFAULTS["synapse_workspace_name_prefix"]),
        ("managed_resource_group_name_prefix", DEFAULTS["synapse_managed_rg_name_prefix"]),
        ("storage_account_name_prefix", DEFAULTS["synapse_storage_account_name_prefix"]),
        ("filesystem_name", filesystem_name),
        ("sql_admin_login", sql_admin_login),
        ("sql_admin_password", sql_admin_password),
        ("aad_admin_login", aad_admin_login),
        ("aad_admin_object_id", aad_admin_object_id),
        ("storage_role_definition_name", DEFAULTS["synapse_storage_role_definition_name"]),
    ]
    if shared_storage_account_id:
        items.append(("shared_storage_account_id", shared_storage_account_id))
    write_tfvars(synapse_dir / "terraform.tfvars", items)


def destroy_stack(tf_dir):
    if not tf_dir.exists():
        raise FileNotFoundError(f"Missing Terraform dir: {tf_dir}")
    run(["terraform", f"-chdir={tf_dir}", "destroy", "-auto-approve"])


if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser(description="Destroy Terraform stacks for AdventureWorks.")
        group = parser.add_mutually_exclusive_group()
        group.add_argument("--rg-only", action="store_true", help="Destroy only the resource group stack")
        group.add_argument("--storage-only", action="store_true", help="Destroy only the storage account stack")
        group.add_argument("--datafactory-only", action="store_true", help="Destroy only the data factory stack")
        group.add_argument("--adf-links-only", action="store_true", help="Destroy only the ADF linked services stack")
        group.add_argument("--adf-pipeline-only", action="store_true", help="Destroy only the ADF pipeline stack")
        group.add_argument("--databricks-only", action="store_true", help="Destroy only the Databricks stack")
        group.add_argument(
            "--databricks-access-only",
            action="store_true",
            help="Destroy only the Databricks access connector stack",
        )
        group.add_argument(
            "--databricks-adls-sp-only",
            action="store_true",
            help="Destroy only the ADLS OAuth service principal stack",
        )
        group.add_argument("--databricks-cluster-only", action="store_true", help="Destroy only the Databricks cluster stack")
        group.add_argument(
            "--databricks-notebooks-only",
            action="store_true",
            help="Destroy only the Databricks notebooks stack",
        )
        group.add_argument("--synapse-only", action="store_true", help="Destroy only the Synapse Analytics stack")
        args = parser.parse_args()

        repo_root = Path(__file__).resolve().parent.parent
        load_env_file(repo_root / ".env")

        rg_dir = repo_root / "terraform" / "01_resource_group"
        storage_dir = repo_root / "terraform" / "02_storage_account"
        data_factory_dir = repo_root / "terraform" / "03_data_factory"
        linked_services_dir = repo_root / "terraform" / "04_adf_linked_services"
        pipeline_dir = repo_root / "terraform" / "05_adf_pipeline_http"
        databricks_dir = repo_root / "terraform" / "06_databricks"
        databricks_access_dir = repo_root / "terraform" / "08_databricks_access_connector"
        adls_oauth_dir = repo_root / "terraform" / "09_databricks_adls_sp"
        databricks_cluster_dir = repo_root / "terraform" / "07_databricks_cluster"
        databricks_notebooks_dir = repo_root / "terraform" / "10_databricks_notebooks"
        synapse_dir = repo_root / "terraform" / "11_synapse_analytics"

        if args.storage_only:
            rg_name = get_rg_name(rg_dir)
            if not rg_name:
                raise RuntimeError("Resource group name not found for storage destroy.")
            write_storage_tfvars(storage_dir, rg_name)
            destroy_stack(storage_dir)
            sys.exit(0)

        if args.datafactory_only:
            rg_name = get_rg_name(rg_dir)
            if not rg_name:
                raise RuntimeError("Resource group name not found for data factory destroy.")
            write_data_factory_tfvars(data_factory_dir, rg_name)
            destroy_stack(data_factory_dir)
            sys.exit(0)

        if args.adf_links_only:
            if not state_has_resources(linked_services_dir):
                print("No ADF linked services state found; skipping destroy.")
                sys.exit(0)
            write_adf_linked_services_tfvars(linked_services_dir, data_factory_dir, storage_dir)
            destroy_stack(linked_services_dir)
            sys.exit(0)

        if args.adf_pipeline_only:
            if not state_has_resources(pipeline_dir):
                print("No ADF pipeline state found; skipping destroy.")
                sys.exit(0)
            write_adf_pipeline_tfvars(pipeline_dir, data_factory_dir, linked_services_dir)
            destroy_stack(pipeline_dir)
            sys.exit(0)

        if args.databricks_only:
            rg_name = get_rg_name(rg_dir)
            if not rg_name:
                raise RuntimeError("Resource group name not found for Databricks destroy.")
            write_databricks_tfvars(databricks_dir, rg_name)
            destroy_stack(databricks_dir)
            sys.exit(0)

        if args.databricks_access_only:
            rg_name = get_rg_name(rg_dir)
            if not rg_name:
                raise RuntimeError("Resource group name not found for Databricks access destroy.")
            storage_account_id = get_storage_account_id(storage_dir)
            if not storage_account_id:
                raise RuntimeError("Storage account ID not found for Databricks access destroy.")
            write_databricks_access_tfvars(databricks_access_dir, rg_name, storage_account_id)
            destroy_stack(databricks_access_dir)
            sys.exit(0)

        if args.databricks_adls_sp_only:
            rg_name = get_rg_name(rg_dir)
            if not rg_name:
                raise RuntimeError("Resource group name not found for ADLS OAuth destroy.")
            storage_account_id = get_storage_account_id(storage_dir)
            if not storage_account_id:
                raise RuntimeError("Storage account ID not found for ADLS OAuth destroy.")
            write_adls_oauth_tfvars(adls_oauth_dir, rg_name, storage_account_id)
            destroy_stack(adls_oauth_dir)
            sys.exit(0)

        if args.databricks_cluster_only:
            write_databricks_cluster_tfvars(databricks_cluster_dir, databricks_dir)
            destroy_stack(databricks_cluster_dir)
            sys.exit(0)

        if args.databricks_notebooks_only:
            if not state_has_resources(databricks_notebooks_dir):
                print("No Databricks notebooks state found; skipping destroy.")
                sys.exit(0)
            write_databricks_notebooks_tfvars(databricks_notebooks_dir, databricks_dir, databricks_cluster_dir)
            destroy_stack(databricks_notebooks_dir)
            sys.exit(0)

        if args.synapse_only:
            if not state_has_resources(synapse_dir):
                print("No Synapse Analytics state found; skipping destroy.")
                sys.exit(0)
            rg_name = get_rg_name(rg_dir)
            if not rg_name:
                raise RuntimeError("Resource group name not found for Synapse destroy.")
            storage_account_id = get_storage_account_id(storage_dir)
            write_synapse_tfvars(synapse_dir, rg_name, storage_account_id)
            destroy_stack(synapse_dir)
            sys.exit(0)

        if args.rg_only:
            destroy_stack(rg_dir)
            sys.exit(0)

        rg_name = get_rg_name(rg_dir)
        if not rg_name:
            raise RuntimeError("Resource group name not found for storage destroy.")

        write_storage_tfvars(storage_dir, rg_name)
        write_data_factory_tfvars(data_factory_dir, rg_name)

        if state_has_resources(pipeline_dir):
            write_adf_pipeline_tfvars(pipeline_dir, data_factory_dir, linked_services_dir)
            destroy_stack(pipeline_dir)
        else:
            print("No ADF pipeline state found; skipping destroy.")

        if state_has_resources(linked_services_dir):
            write_adf_linked_services_tfvars(linked_services_dir, data_factory_dir, storage_dir)
            destroy_stack(linked_services_dir)
        else:
            print("No ADF linked services state found; skipping destroy.")

        if state_has_resources(databricks_notebooks_dir):
            write_databricks_notebooks_tfvars(databricks_notebooks_dir, databricks_dir, databricks_cluster_dir)
            destroy_stack(databricks_notebooks_dir)
        else:
            print("No Databricks notebooks state found; skipping destroy.")

        if state_has_resources(synapse_dir):
            storage_account_id = get_storage_account_id(storage_dir)
            write_synapse_tfvars(synapse_dir, rg_name, storage_account_id)
            destroy_stack(synapse_dir)
        else:
            print("No Synapse Analytics state found; skipping destroy.")

        write_databricks_cluster_tfvars(databricks_cluster_dir, databricks_dir)
        destroy_stack(databricks_cluster_dir)

        storage_account_id = get_storage_account_id(storage_dir)
        if not storage_account_id:
            raise RuntimeError("Storage account ID not found for Databricks access destroy.")

        write_adls_oauth_tfvars(adls_oauth_dir, rg_name, storage_account_id)
        destroy_stack(adls_oauth_dir)

        write_databricks_access_tfvars(databricks_access_dir, rg_name, storage_account_id)
        destroy_stack(databricks_access_dir)

        write_databricks_tfvars(databricks_dir, rg_name)
        destroy_stack(databricks_dir)

        destroy_stack(data_factory_dir)
        destroy_stack(storage_dir)
        destroy_stack(rg_dir)

    except subprocess.CalledProcessError as exc:
        print(f"Command failed: {exc}")
        sys.exit(exc.returncode)
