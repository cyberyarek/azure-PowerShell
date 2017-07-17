# Script to create a point-to-site connection to an Azure VNet

$VNET_NAME                      = "VNet1"

$FE_SUB_NAME                    = "FrontEnd"
$BE_SUB_NAME                    = "BackEnd"
$GW_SUB_NAME                    = "GatewaySubnet"

$VNET_PREFIX1                   = "192.168.0.0/16"
$VNET_PREFIX2                   = "10.254.0.0/16"

$FE_SUB_PREFIX                  = "192.168.1.0/24"
$GW_SUB_PREFIX                  = "192.168.200.0/26"
$BE_SUB_PREFIX                  = "10.254.1.0/24"

$VPN_CLIENT_ADDRESS_POOL        = "172.16.201.0/24"

$RG                             = "TestRG"
$LOCATION                       = "East US"
$DNS                            = "8.8.8.8"

$GW_NAME                        = "VNet1GW"
$GW_IP_NAME                     = "VNet1GWPIP"
$GW_IP_CONF_NAME                = "gwipconf"

New-AzureRmResourceGroup `
  -Name                         $RG `
  -Location                     $LOCATION `


$fesub = New-AzureRmVirtualNetworkSubnetConfig `
  -Name                         $FE_SUB_NAME `
  -AddressPrefix                $FE_SUB_PREFIX `


$besub = New-AzureRmVirtualNetworkSubnetConfig `
  -Name                         $BE_SUB_NAME `
  -AddressPrefix                $BE_SUB_PREFIX `


$gwsub = New-AzureRmVirtualNetworkSubnetConfig `
  -Name                         $GW_SUB_NAME `
  -AddressPrefix                $GW_SUB_PREFIX`


New-AzureRmVirtualNetwork `
  -Name                         $VNET_NAME `
  -ResourceGroupName            $RG `
  -Location                     $LOCATION `
  -AddressPrefix                $VNET_PREFIX1,$VNET_PREFIX2 `
  -Subnet                       $fesub, $besub, $gwsub `
  -DnsServer                    $DNS


$vnet = Get-AzureRmVirtualNetwork `
  -Name                         $VNET_NAME `
  -ResourceGroupName            $RG `


$subnet = Get-AzureRmVirtualNetworkSubnetConfig `
  -Name                         $GW_SUB_NAME `
  -VirtualNetwork               $vnet `
  

$pip = New-AzureRmPublicIpAddress `
  -Name                         $GW_IP_NAME `
  -ResourceGroupName            $RG `
  -Location                     $LOCATION `
  -AllocationMethod             Dynamic `


$ipconf = New-AzureRmVirtualNetworkGatewayIpConfig `
  -Name                         $GW_IP_CONF_NAME `
  -Subnet                       $subnet `
  -PublicIpAddress              $pip `

