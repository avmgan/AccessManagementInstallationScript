$setupOptions.MASTER_PASSWORD = "xxxx"

$setupOptions.IDP_PROVIDER_JSON="azure-idp-provider.json"

# GLOBAL SETTINGS
$setupOptions.LOCAL_HOSTNAME = "localhost"
$setupOptions.SA_ACCOUNT_NAME= "sa"
$setupOptions.SA_PASSWORD=$setupOptions.MASTER_PASSWORD
$setupOptions.DB_HOST="localhost"
$setupOptions.SQL_SERVER_PORT = "1433"

# Access Management Service Database
$setupOptions.AM_DB_HOST = $setupOptions.DB_HOST
$setupOptions.AM_DB_NAME = "TXS_DEMO_Tridion_AccessManagement"
$setupOptions.AM_DB_USER_NAME = "AccessManagementUser"
$setupOptions.AM_DB_PASSWORD = $setupOptions.MASTER_PASSWORD

# TCP Port Options

$setupOptions.PORT_CM_WEB = 7080
$setupOptions.PORT_ACESSMANAEMENT_SERVICE = 84
$setupOptions.PORT_ADDON_SERVICE = 83

$setupOptions.CM_WEB_URL = "http://localhost:"+$setupOptions.PORT_CM_WEB
$setupOptions.ADDON_SERVICE_URL = "http://localhost:"+$setupOptions.PORT_ADDON_SERVICE
$setupOptions.ACCESS_MANAGEMENT_URL = "http://localhost:"+$setupOptions.PORT_ACESSMANAEMENT_SERVICE