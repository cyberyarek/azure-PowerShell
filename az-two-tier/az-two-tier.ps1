# Script to create a VM in Azure

# this removes all variables startinh with AZ_ from global scope... hope you liked those
# foreach ($var in ( get-variable -scope global | Where-Object {$_.Name -match "^AZ_"})) {
#     echo "Removing variable $($var.Name)"
#     echo $var.Value
#     remove-variable -scope global $var.Name
# }

# get-variable | Where-Object {$_.Name -match "^AZ_"}

$AZ_RG_NAME             = "twotier"
$AZ_RG_LOC              = "australiaeast"

$AZ_VM_ADMIN_USERNAME   ="yarek"
$AZ_VM_ADMIN_PASSWORD   ="ASDFqwer1234@;:."


echo "--------------------------------"
echo "| Credentials "
echo "--------------------------------"

$azurePassword = ConvertTo-SecureString $AZ_VM_ADMIN_PASSWORD -AsPlainText -Force
$vmCred = New-Object System.Management.Automation.PSCredential($AZ_VM_ADMIN_USERNAME, $azurePassword)



$AZ_VNET_NAME           = ${AZ_RG_NAME} + "-vnet"
$AZ_VNET_LOC            = ${AZ_RG_LOC}
$AZ_VNET_PREFIX         = "10.1"
$AZ_VNET_CIDR           = ${AZ_VNET_PREFIX} + ".0.0/16"

$AZ_WEB_TIER_NAME       = "web"

$AZ_WEB_SUBNET_NAME     = ${AZ_VNET_NAME} + "-" + ${AZ_WEB_TIER_NAME}
$AZ_WEB_SUBNET_PREFIX   = ${AZ_VNET_PREFIX} + ".1"
$AZ_WEB_SUBNET_CIDR     = ${AZ_WEB_SUBNET_PREFIX} + ".0/24"


$AZ_DB_TIER_NAME        = "db"

$AZ_DB_SUBNET_NAME      = ${AZ_VNET_NAME} + "-" + ${AZ_DB_TIER_NAME}
$AZ_DB_SUBNET_PREFIX    = ${AZ_VNET_PREFIX} + ".2"
$AZ_DB_SUBNET_CIDR      = ${AZ_DB_SUBNET_PREFIX} + ".0/24"


#################################################################
# Create a new resource group
#################################################################
echo "################################"
echo "# Resource Group"
echo "################################"
New-AzureRmResourceGroup -Name $AZ_RG_NAME -Location $AZ_RG_LOC


echo ""
#################################################################
# Create a Web subnet configuration
#################################################################
echo "################################"
echo "# VNet's Web Subnet"
echo "################################"
$webSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig `
  -Name                 $AZ_WEB_SUBNET_NAME `
  -AddressPrefix        $AZ_WEB_SUBNET_CIDR `
  

echo ""
#################################################################
# Create a Web subnet configuration
#################################################################
echo "################################"
echo "# VNet's DB Subnet"
echo "################################"
$dbSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig `
  -Name                 $AZ_DB_SUBNET_NAME `
  -AddressPrefix        $AZ_DB_SUBNET_CIDR `
  

echo ""
#################################################################
# Create a virtual network
#################################################################
echo "################################"
echo "# Virtual Network"
echo "################################"
$vnet = New-AzureRmVirtualNetwork `
  -Name                 $AZ_VNET_NAME `
  -Location             $AZ_VNET_LOC `
  -AddressPrefix        $AZ_VNET_CIDR `
  -Subnet               $webSubnetConfig, $dbSubnetConfig `
  -ResourceGroupName    $AZ_RG_NAME `

# Get the subnet values back from the VNet to get full config info
$dbSubnetConfig = $vnet | Get-AzureRmVirtualNetworkSubnetConfig -Name $AZ_DB_SUBNET_NAME
$webSubnetConfig = $vnet | Get-AzureRmVirtualNetworkSubnetConfig -Name $AZ_WEB_SUBNET_NAME

$dbSubnetConfig, $webSubnetConfig | Format-Table

echo ""
#################################################################
echo "################################"
echo "# Subnets List"
echo "################################"
Get-AzureRmVirtualNetwork `
  -Name                 $AZ_VNET_NAME `
  -ResourceGroupName    $AZ_RG_NAME `
  | Get-AzureRmVirtualNetworkSubnetConfig `
  | Format-Table


echo ""
#################################################################
# Create a public IP address and specify a DNS name
#################################################################
echo "################################"
echo "# Web Public IP "
echo "################################"

$AZ_WEB_PUBLIC_IP_NAME          = $AZ_WEB_SUBNET_NAME + "-pip"
$AZ_WEB_PUBLIC_IP_LOC           = $AZ_RG_LOC
$AZ_WEB_PUBLIC_IP_DNSNAME       = ${AZ_VM_ADMIN_USERNAME}+${AZ_RG_NAME} -replace "-",""
$AZ_WEB_PUBLIC_IP_TIMEOUT       = "4"
$AZ_WEB_PUBLIC_IP_ALLOCATION    = "Static"

$webPip = New-AzureRmPublicIpAddress `
  -Name                 $AZ_WEB_PUBLIC_IP_NAME `
  -Location             $AZ_WEB_PUBLIC_IP_LOC `
  -AllocationMethod     $AZ_WEB_PUBLIC_IP_ALLOCATION `
  -DomainNameLabel      $AZ_WEB_PUBLIC_IP_DNSNAME `
  -IdleTimeoutInMinutes $AZ_WEB_PUBLIC_IP_TIMEOUT `
  -ResourceGroupName    $AZ_RG_NAME `

$webPip | Format-Table


$AZ_WEB_LB_NAME         =${AZ_WEB_SUBNET_NAME} + "-lb"
$AZ_WEB_LB_LOC          =${AZ_RG_LOC}
$AZ_WEB_LB_BE_NAME      =${AZ_WEB_LB_NAME} + "-be"
$AZ_WEB_LB_FE_NAME      =${AZ_WEB_LB_NAME} + "-fe"

echo ""
################################################################
echo "################################"
echo "# Web LB FE and BE Configs"
echo "################################"


$webFEConfig = New-AzureRmLoadBalancerFrontendIpConfig `
  -Name                 $AZ_WEB_LB_FE_NAME `
  -PublicIpAddress      $webPip `


$webFEConfig | Format-Table


$webBEConfig = New-AzureRmLoadBalancerBackendAddressPoolConfig `
  -Name                 $AZ_WEB_LB_BE_NAME `


$webBEConfig | Format-Table

echo ""
################################################################
echo "################################"
echo "# Web LB inbound NAT rules"
echo "################################"

$AZ_WEB_LB_NAT_RULE_PROTOCOL="tcp"

$AZ_WEB_LB_NAT_RULE1_NAME       = ${AZ_WEB_LB_NAME} + "-nat-rdp1"
$AZ_WEB_LB_NAT_RULE1_FE_PORT    = "3441"
$AZ_WEB_LB_NAT_RULE1_BE_PORT    = "3389"

$AZ_WEB_LB_NAT_RULE2_NAME       =${AZ_WEB_LB_NAME} + "-nat-rdp2"
$AZ_WEB_LB_NAT_RULE2_FE_PORT    ="3442"
$AZ_WEB_LB_NAT_RULE2_BE_PORT    ="3389"


$webNATRule1= New-AzureRmLoadBalancerInboundNatRuleConfig `
  -Name                         $AZ_WEB_LB_NAT_RULE1_NAME `
  -FrontendIpConfiguration      $webFEConfig `
  -Protocol                     $AZ_WEB_LB_NAT_RULE_PROTOCOL `
  -FrontendPort                 $AZ_WEB_LB_NAT_RULE1_FE_PORT `
  -BackendPort                  $AZ_WEB_LB_NAT_RULE1_BE_PORT `


$webNATRule2= New-AzureRmLoadBalancerInboundNatRuleConfig `
  -Name                         $AZ_WEB_LB_NAT_RULE2_NAME `
  -FrontendIpConfiguration      $webFEConfig `
  -Protocol                     $AZ_WEB_LB_NAT_RULE_PROTOCOL `
  -FrontendPort                 $AZ_WEB_LB_NAT_RULE2_FE_PORT `
  -BackendPort                  $AZ_WEB_LB_NAT_RULE2_BE_PORT `


$webNATRule1, $webNATRule2 | Format-Table

echo ""
################################################################
echo "################################"
echo "# Web LB health probe"
echo "################################"

$AZ_WEB_LB_RULE_PROTOCOL                = "tcp"
$AZ_WEB_LB_RULE_FE_PORT                 = "80"
$AZ_WEB_LB_RULE_NAME                    = ${AZ_WEB_LB_NAME} + "-" + ${AZ_WEB_LB_RULE_PROTOCOL}

$AZ_WEB_LB_RULE_HEALTH_PROBE_NAME       = ${AZ_WEB_LB_RULE_NAME} + "-probe-" + ${AZ_WEB_LB_RULE_FE_PORT}
$AZ_WEB_LB_RULE_HEALTH_PROBE_PATH       = "HealthProbe.aspx"
$AZ_WEB_LB_RULE_HEALTH_PROBE_PROTOCOL   = "http"
$AZ_WEB_LB_RULE_HEALTH_PROBE_INTERVAL   = "15"
$AZ_WEB_LB_RULE_HEALTH_PROBE_THRESHOLD  = "2"


# add the health probe to configuration
$webHealthProbe = New-AzureRmLoadBalancerProbeConfig `
  -Name                 $AZ_WEB_LB_RULE_HEALTH_PROBE_NAME `
  -RequestPath          $AZ_WEB_LB_RULE_HEALTH_PROBE_PATH  `
  -Port                 $AZ_WEB_LB_RULE_FE_PORT `
  -Protocol             $AZ_WEB_LB_RULE_HEALTH_PROBE_PROTOCOL  `
  -IntervalInSeconds    $AZ_WEB_LB_RULE_HEALTH_PROBE_INTERVAL `
  -ProbeCount           $AZ_WEB_LB_RULE_HEALTH_PROBE_THRESHOLD `


$webHealthProbe | Format-Table

echo ""
################################################################
echo "################################"
echo "# Web LB rule"
echo "################################"

$AZ_WEB_LB_RULE_BE_PORT=${AZ_WEB_LB_RULE_FE_PORT}


# add the health probe to configuration
$webRule = New-AzureRmLoadBalancerRuleConfig `
  -Name                         $AZ_WEB_LB_RULE_NAME `
  -Protocol                     $AZ_WEB_LB_RULE_PROTOCOL `
  -FrontendPort                 $AZ_WEB_LB_RULE_FE_PORT `
  -BackendPort                  $AZ_WEB_LB_RULE_BE_PORT `
  -FrontendIpConfiguration      $webFEConfig `
  -BackendAddressPool           $webBEConfig `
  -Probe                        $webHealthProbe `


$webRule | Format-Table


echo ""
################################################################
echo "################################"
echo "# Web LB "
echo "################################"


$webLB = New-AzureRmLoadBalancer `
  -ResourceGroupName            $AZ_RG_NAME `
  -Name                         $AZ_WEB_LB_NAME `
  -Location                     $AZ_WEB_LB_LOC `
  -FrontendIpConfiguration      $webFEConfig `
  -BackendAddressPool           $webBEConfig `
  -InboundNatRule               $webNATRule1,$webNATRule2 `
  -LoadBalancingRule            $webRule `
  -Probe                        $webHealthProbe `


Get-AzureRmLoadBalancer `
  -ResourceGroupName    $AZ_RG_NAME `
  -Name                 $AZ_WEB_LB_NAME `
  | Format-Table


echo ""
################################################################
echo "################################"
echo "# DB LB FE and BE Configs"
echo "################################"

$AZ_DB_LB_NAME          = ${AZ_DB_SUBNET_NAME}+"-lb"
$AZ_DB_LB_LOC           = ${AZ_RG_LOC}
$AZ_DB_LB_PRIVATE_IP    = ${AZ_DB_SUBNET_PREFIX}+".5"
$AZ_DB_LB_BE_NAME       = ${AZ_DB_LB_NAME}+"-be"
$AZ_DB_LB_FE_NAME       = ${AZ_DB_LB_NAME}+"-fe"

$dbFEConfig = New-AzureRmLoadBalancerFrontendIpConfig `
  -Name                 $AZ_DB_LB_FE_NAME `
  -PrivateIpAddress     $AZ_DB_LB_PRIVATE_IP `
  -Subnet               $dbSubnetConfig `


$dbFEConfig | Format-Table


$dbBEConfig = New-AzureRmLoadBalancerBackendAddressPoolConfig `
  -Name                 $AZ_DB_LB_BE_NAME `


$dbBEConfig | Format-Table


echo ""
################################################################
echo "################################"
echo "# DB LB inbound NAT rules"
echo "################################"

$AZ_DB_LB_NAT_RULE_PROTOCOL     = "tcp"

$AZ_DB_LB_NAT_RULE1_NAME        =${AZ_DB_LB_NAME}+"-nat-rdp1"
$AZ_DB_LB_NAT_RULE1_FE_PORT     ="3443"
$AZ_DB_LB_NAT_RULE1_BE_PORT     ="3389"

$AZ_DB_LB_NAT_RULE2_NAME        =${AZ_DB_LB_NAME}+"-nat-rdp2"
$AZ_DB_LB_NAT_RULE2_FE_PORT     ="3444"
$AZ_DB_LB_NAT_RULE2_BE_PORT     ="3389"

$dbNATRule1= New-AzureRmLoadBalancerInboundNatRuleConfig `
  -Name                         $AZ_DB_LB_NAT_RULE1_NAME `
  -FrontendIpConfiguration      $dbFEConfig `
  -Protocol                     $AZ_DB_LB_NAT_RULE_PROTOCOL `
  -FrontendPort                 $AZ_DB_LB_NAT_RULE1_FE_PORT `
  -BackendPort                  $AZ_DB_LB_NAT_RULE1_BE_PORT `


$dbNATRule2= New-AzureRmLoadBalancerInboundNatRuleConfig `
  -Name                         $AZ_DB_LB_NAT_RULE2_NAME `
  -FrontendIpConfiguration      $dbFEConfig `
  -Protocol                     $AZ_DB_LB_NAT_RULE_PROTOCOL `
  -FrontendPort                 $AZ_DB_LB_NAT_RULE2_FE_PORT `
  -BackendPort                  $AZ_DB_LB_NAT_RULE2_BE_PORT `


$dbNATRule1, $dbNATRule2 | Format-Table


echo ""
################################################################
echo "################################"
echo "# DB LB health probe"
echo "################################"

$AZ_DB_LB_RULE_PROTOCOL                 = "tcp"
$AZ_DB_LB_RULE_FE_PORT                  = "1433"
$AZ_DB_LB_RULE_NAME                     = ${AZ_DB_LB_NAME} + "-" + ${AZ_DB_LB_RULE_PROTOCOL}

$AZ_DB_LB_RULE_HEALTH_PROBE_NAME        = ${AZ_DB_LB_RULE_NAME} + "-probe-" + ${AZ_DB_LB_RULE_FE_PORT}
$AZ_DB_LB_RULE_HEALTH_PROBE_PROTOCOL    = "tcp"
$AZ_DB_LB_RULE_HEALTH_PROBE_INTERVAL    = "15"
$AZ_DB_LB_RULE_HEALTH_PROBE_THRESHOLD   = "2"

# add the health probe to configuration
$dbHealthProbe = New-AzureRmLoadBalancerProbeConfig `
  -Name                 $AZ_DB_LB_RULE_HEALTH_PROBE_NAME `
  -Port                 $AZ_DB_LB_RULE_FE_PORT `
  -Protocol             $AZ_DB_LB_RULE_HEALTH_PROBE_PROTOCOL  `
  -IntervalInSeconds    $AZ_DB_LB_RULE_HEALTH_PROBE_INTERVAL `
  -ProbeCount           $AZ_DB_LB_RULE_HEALTH_PROBE_THRESHOLD `


$dbHealthProbe | Format-Table

echo ""
################################################################
echo "################################"
echo "# DB LB rule"
echo "################################"

$AZ_DB_LB_RULE_BE_PORT=${AZ_DB_LB_RULE_FE_PORT}


# add the health probe to configuration
$dbRule = New-AzureRmLoadBalancerRuleConfig `
  -Name                         $AZ_DB_LB_RULE_NAME `
  -Protocol                     $AZ_DB_LB_RULE_PROTOCOL `
  -FrontendPort                 $AZ_DB_LB_RULE_FE_PORT `
  -BackendPort                  $AZ_DB_LB_RULE_BE_PORT `
  -FrontendIpConfiguration      $dbFEConfig `
  -BackendAddressPool           $dbBEConfig `
  -Probe                        $dbHealthProbe `


$dbRule | Format-Table


echo ""
################################################################
echo "################################"
echo "# DB LB "
echo "################################"


$dbLB = New-AzureRmLoadBalancer `
  -ResourceGroupName            $AZ_RG_NAME `
  -Name                         $AZ_DB_LB_NAME `
  -Location                     $AZ_DB_LB_LOC `
  -FrontendIpConfiguration      $dbFEConfig `
  -BackendAddressPool           $dbBEConfig `
  -InboundNatRule               $dbNATRule1,$dbNATRule2 `
  -LoadBalancingRule            $dbRule `
  -Probe                        $dbHealthProbe `


Get-AzureRmLoadBalancer `
  -ResourceGroupName    $AZ_RG_NAME `
  -Name                 $AZ_DB_LB_NAME `
  | Format-Table


echo ""
################################################################
echo "################################"
echo "# Web NIC creation"
echo "################################"

$AZ_WEB_NIC1_NAME = ${AZ_WEB_SUBNET_NAME} + "-1-nic"
$AZ_WEB_NIC2_NAME = ${AZ_WEB_SUBNET_NAME} + "-2-nic"

$webBEConfig = $webLB | Get-AzureRmLoadBalancerBackendAddressPoolConfig `
  -Name $AZ_WEB_LB_BE_NAME

$webNATRule1 = $webLB | Get-AzureRmLoadBalancerInboundNatRuleConfig `
  -Name $AZ_WEB_LB_NAT_RULE1_NAME

$webNATRule2 = $webLB | Get-AzureRmLoadBalancerInboundNatRuleConfig `
  -Name $AZ_WEB_LB_NAT_RULE2_NAME

$webNic1 = New-AzureRmNetworkInterface `
  -ResourceGroupName                    $AZ_RG_NAME `
  -Name                                 $AZ_WEB_NIC1_NAME `
  -Location                             $AZ_VNET_LOC `
  -Subnet                               $webSubnetConfig `
  -LoadBalancerBackendAddressPool       $webBEConfig `
  -LoadBalancerInboundNatRule           $webNATRule1 `

$webNic2 = New-AzureRmNetworkInterface `
  -ResourceGroupName                    $AZ_RG_NAME `
  -Name                                 $AZ_WEB_NIC2_NAME `
  -Location                             $AZ_VNET_LOC `
  -Subnet                               $webSubnetConfig `
  -LoadBalancerBackendAddressPool       $webBEConfig `
  -LoadBalancerInboundNatRule           $weNATRule2 `


Get-AzureRmNetworkInterface `
  -ResourceGroupName                    $AZ_RG_NAME `
  | Format-Table


echo ""
################################################################
echo "################################"
echo "# DB NIC creation"
echo "################################"

$AZ_DB_NIC1_NAME = ${AZ_DB_SUBNET_NAME} + "-1-nic"
$AZ_DB_NIC2_NAME = ${AZ_DB_SUBNET_NAME} + "-2-nic"

$dbBEConfig = $dbLB | Get-AzureRmLoadBalancerBackendAddressPoolConfig `
  -Name $AZ_DB_LB_BE_NAME

$dbNATRule1 = $dbLB | Get-AzureRmLoadBalancerInboundNatRuleConfig `
  -Name $AZ_DB_LB_NAT_RULE1_NAME

$dbNATRule2 = $dbLB | Get-AzureRmLoadBalancerInboundNatRuleConfig `
  -Name $AZ_DB_LB_NAT_RULE2_NAME

$dbNic1 = New-AzureRmNetworkInterface `
  -ResourceGroupName                    $AZ_RG_NAME `
  -Name                                 $AZ_DB_NIC1_NAME `
  -Location                             $AZ_VNET_LOC `
  -Subnet                               $dbSubnetConfig `
  -LoadBalancerBackendAddressPool       $dbBEConfig `
  -LoadBalancerInboundNatRule           $dbNATRule1 `

$dbNic2 = New-AzureRmNetworkInterface `
  -ResourceGroupName                    $AZ_RG_NAME `
  -Name                                 $AZ_DB_NIC2_NAME `
  -Location                             $AZ_VNET_LOC `
  -Subnet                               $dbSubnetConfig `
  -LoadBalancerBackendAddressPool       $dbBEConfig `
  -LoadBalancerInboundNatRule           $dbNATRule2 `


Get-AzureRmNetworkInterface `
  -ResourceGroupName                    $AZ_RG_NAME `
  | Format-Table


echo ""
################################################################
echo "################################"
echo "# Web VMs with NICs"
echo "################################"

$AZ_WEB_VM_PREFIX               = "vm-" + ${AZ_WEB_TIER_NAME}

$AZ_WEB_VM_AVAILSET_NAME        = ${AZ_WEB_VM_PREFIX} + "-as"
$AZ_WEB_VM_AVAILSET_LOC         = ${AZ_WEB_LB_LOC}
$AZ_WEB_VM_AVAILSET_FAULT       = "2"

$AZ_WEB_VM1_NAME                = ${AZ_WEB_VM_PREFIX} + "-1"
$AZ_WEB_VM2_NAME                = ${AZ_WEB_VM_PREFIX} + "-2"

# $AZ_WEB_VM1_DISK_NAME           = "${AZ_WEB_VM1_NAME}-disk"
# $AZ_WEB_VM2_DISK_NAME           = "${AZ_WEB_VM2_NAME}-disk"

# $AZ_WEB_VM_DISK_TYPE            = "StandardLRS"
# $AZ_WEB_VM_DISK_SIZE            = 128

$AZ_WEB_VM_LOC                  = ${AZ_WEB_VM_AVAILSET_LOC}
$AZ_WEB_VM_IMAGE                = @{
    "PublisherName"     = "MicrosoftWindowsServer";
    "Offer"             = "WindowsServer";
    "Skus"              = "2016-Datacenter";
    "Version"           = "latest";
}
$AZ_WEB_VM_SIZE                 = "Standard_DS1"

# # Create a new storage account.
# $AZ_STORAGE_ACCOUNT_NAME = $AZ_RG_NAME + "vhdstorage"
# $AZ_STORAGE_ACCOUNT_SKU  = "Premium_LRS"
# #$AZ_STORAGE_ACCOUNT_SKU  = "Standard_LRS"
# $AZ_STORAGE_ACCOUNT_KIND = "Storage"

# echo "--------------------------------"
# echo "| Storage Account "
# echo "--------------------------------"

# $AZ_STORAGE_ACCOUNT = New-AzureRmStorageAccount `
#   -ResourceGroupName    $AZ_RG_NAME `
#   -Name                 $AZ_STORAGE_ACCOUNT_NAME `
#   -SkuName              $AZ_STORAGE_ACCOUNT_SKU `
#   -Kind                 $AZ_STORAGE_ACCOUNT_KIND `
#   -Location             $AZ_RG_LOC `


echo "--------------------------------"
echo "| Availability Set "
echo "--------------------------------"
# The availablity Set
$webVMAvailabitySet = New-AzureRmAvailabilitySet `
  -ResourceGroupName            $AZ_RG_NAME `
  -Location                     $AZ_WEB_VM_LOC `
  -Name                         $AZ_WEB_VM_AVAILSET_NAME `
  -PlatformFaultDomainCount     $AZ_WEB_VM_AVAILSET_FAULT `
  -Sku                          "Aligned" `
  -Managed


# $AZ_WEB_VM1_DISK_URI= $AZ_STORAGE_ACCOUNT.PrimaryEndpoints.Blob.ToString() + "vhds/" + $AZ_WEB_VM1_DISK_NAME + ".vhd"

# $diskConfig =   Set-AzureRmVMSourceImage `
#   -PublisherName      $AZ_WEB_VM_IMAGE.PublisherName `
#   -Offer              $AZ_WEB_VM_IMAGE.Offer `
#   -Skus                       $AZ_WEB_VM_IMAGE.Skus `
#   -Version            $AZ_WEB_VM_IMAGE.Version `

# echo "--------------------------------"
# echo "| OS Disk "
# echo "--------------------------------"

# $diskConfig = New-AzureRmDiskConfig `
#   -AccountType          $AZ_WEB_VM_DISK_TYPE  `
#   -Location             $AZ_WEB_VM_LOC `
#   -DiskSizeGB           $AZ_WEB_VM_DISK_SIZE `
#   -CreateOption         Empty

# #  -StorageAccountId     $AZ_STORAGE_ACCOUNT.id `

# #Create Managed disk
# $webVMOSDisk1 = New-AzureRmDisk `
#   -ResourceGroupName    $AZ_RG_NAME `
#   -DiskName             $AZ_WEB_VM1_DISK_NAME `
#   -Disk                 $diskConfig `

echo "--------------------------------"
echo "| Web VM1 Config "
echo "--------------------------------"

# Create a virtual machine configuration
$webVM1Config = New-AzureRmVMConfig `
  -VMName               $AZ_WEB_VM1_NAME `
  -VMSize               $AZ_WEB_VM_SIZE `
  -AvailabilitySet      $webVMAvailabitySet.Id `
  | Set-AzureRmVMOperatingSystem `
  -Windows `
  -ComputerName         $AZ_WEB_VM1_NAME `
  -Credential           $vmCred `
  | Set-AzureRmVMSourceImage `
  -PublisherName        $AZ_WEB_VM_IMAGE.PublisherName `
  -Offer                $AZ_WEB_VM_IMAGE.Offer `
  -Skus                 $AZ_WEB_VM_IMAGE.Skus `
  -Version              $AZ_WEB_VM_IMAGE.Version `
  | Add-AzureRmVMNetworkInterface `
  -Id                   $webNic1.Id `
  

  # | Set-AzureRmVMOSDisk `
  # -Name                 $AZ_WEB_VM1_DISK_NAME `
  # -VhdUri               $AZ_WEB_VM1_DISK_URI `
  # -DiskSizeInGB         $AZ_WEB_VM_DISK_SIZE `
  # -ManagedDiskId        $webVMOSDisk1.id `
  # -CreateOption         FromImage `
  # -Caching              ReadWrite  `

#  -StorageAccountType   $AZ_WEB_VM_DISK_TYPE `


echo "--------------------------------"
echo "| Web VM1 "
echo "--------------------------------"

$webVM1 = New-AzureRmVM `
  -ResourceGroupName    $AZ_RG_NAME `
  -Location             $AZ_WEB_VM_LOC `
  -VM                   $webVM1Config `



echo "--------------------------------"
echo "| Web VM2 Config "
echo "--------------------------------"

# Create a virtual machine configuration
$webVM2Config = New-AzureRmVMConfig `
  -VMName               $AZ_WEB_VM2_NAME `
  -VMSize               $AZ_WEB_VM_SIZE `
  -AvailabilitySet      $webVMAvailabitySet.Id `
  | Set-AzureRmVMOperatingSystem `
  -Windows `
  -ComputerName         $AZ_WEB_VM2_NAME `
  -Credential           $vmCred `
  | Set-AzureRmVMSourceImage `
  -PublisherName        $AZ_WEB_VM_IMAGE.PublisherName `
  -Offer                $AZ_WEB_VM_IMAGE.Offer `
  -Skus                 $AZ_WEB_VM_IMAGE.Skus `
  -Version              $AZ_WEB_VM_IMAGE.Version `
  | Add-AzureRmVMNetworkInterface `
  -Id                   $webNic2.Id `
  

echo "--------------------------------"
echo "| Web VM2 "
echo "--------------------------------"

$webVM2 = New-AzureRmVM `
  -ResourceGroupName    $AZ_RG_NAME `
  -Location             $AZ_WEB_VM_LOC `
  -VM                   $webVM2Config `




echo ""
################################################################
echo "################################"
echo "# DB VMs with NICs"
echo "################################"

$AZ_DB_VM_PREFIX               = "vm-" + ${AZ_DB_TIER_NAME}

$AZ_DB_VM_AVAILSET_NAME        = ${AZ_DB_VM_PREFIX} + "-as"
$AZ_DB_VM_AVAILSET_LOC         = ${AZ_DB_LB_LOC}
$AZ_DB_VM_AVAILSET_FAULT       = "2"

$AZ_DB_VM1_NAME                = ${AZ_DB_VM_PREFIX} + "-1"
$AZ_DB_VM2_NAME                = ${AZ_DB_VM_PREFIX} + "-2"

$AZ_DB_VM_LOC                  = ${AZ_DB_VM_AVAILSET_LOC}
$AZ_DB_VM_IMAGE                = @{
    "PublisherName"     = "MicrosoftWindowsServer";
    "Offer"             = "WindowsServer";
    "Skus"              = "2016-Datacenter";
    "Version"           = "latest";
}
$AZ_DB_VM_SIZE                 = "Standard_DS1"

echo "--------------------------------"
echo "| Availability Set "
echo "--------------------------------"
# The availablity Set
$dbVMAvailabitySet = New-AzureRmAvailabilitySet `
  -ResourceGroupName            $AZ_RG_NAME `
  -Location                     $AZ_DB_VM_LOC `
  -Name                         $AZ_DB_VM_AVAILSET_NAME `
  -PlatformFaultDomainCount     $AZ_DB_VM_AVAILSET_FAULT `
  -Sku                          "Aligned" `
  -Managed


echo "--------------------------------"
echo "| DB VM1 Config "
echo "--------------------------------"

# Create a virtual machine configuration
$dbVM1Config = New-AzureRmVMConfig `
  -VMName               $AZ_DB_VM1_NAME `
  -VMSize               $AZ_DB_VM_SIZE `
  -AvailabilitySet      $dbVMAvailabitySet.Id `
  | Set-AzureRmVMOperatingSystem `
  -Windows `
  -ComputerName         $AZ_DB_VM1_NAME `
  -Credential           $vmCred `
  | Set-AzureRmVMSourceImage `
  -PublisherName        $AZ_DB_VM_IMAGE.PublisherName `
  -Offer                $AZ_DB_VM_IMAGE.Offer `
  -Skus                 $AZ_DB_VM_IMAGE.Skus `
  -Version              $AZ_DB_VM_IMAGE.Version `
  | Add-AzureRmVMNetworkInterface `
  -Id                   $dbNic1.Id `
  

echo "--------------------------------"
echo "| DB VM1 "
echo "--------------------------------"

$dbVM1 = New-AzureRmVM `
  -ResourceGroupName    $AZ_RG_NAME `
  -Location             $AZ_DB_VM_LOC `
  -VM                   $dbVM1Config `



echo "--------------------------------"
echo "| DB VM2 Config "
echo "--------------------------------"

# Create a virtual machine configuration
$dbVM2Config = New-AzureRmVMConfig `
  -VMName               $AZ_DB_VM2_NAME `
  -VMSize               $AZ_DB_VM_SIZE `
  -AvailabilitySet      $dbVMAvailabitySet.Id `
  | Set-AzureRmVMOperatingSystem `
  -Windows `
  -ComputerName         $AZ_DB_VM2_NAME `
  -Credential           $vmCred `
  | Set-AzureRmVMSourceImage `
  -PublisherName        $AZ_DB_VM_IMAGE.PublisherName `
  -Offer                $AZ_DB_VM_IMAGE.Offer `
  -Skus                 $AZ_DB_VM_IMAGE.Skus `
  -Version              $AZ_DB_VM_IMAGE.Version `
  | Add-AzureRmVMNetworkInterface `
  -Id                   $dbNic2.Id `
  

echo "--------------------------------"
echo "| DB VM2 "
echo "--------------------------------"

$dbVM2 = New-AzureRmVM `
  -ResourceGroupName    $AZ_RG_NAME `
  -Location             $AZ_DB_VM_LOC `
  -VM                   $dbVM2Config `






