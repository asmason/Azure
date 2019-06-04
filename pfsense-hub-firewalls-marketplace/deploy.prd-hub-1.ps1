Add-AzureRmAccount

$subscriptionId = '935e6bd0-1a03-4fe6-8d8d-d1ecfd5a670b'
$resourceGroupName = 'rg-prd-vm-pfs-1'
$location = 'northeurope'
$templateFile = 'azuredeploy.json'
$templateParameterFile = 'azuredeploy.prd-hub-1.parameters.json'

Select-AzureRmSubscription -Subscription $subscriptionId

New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

$testErrors = Test-AzureRmResourceGroupDeployment -TemplateFile $templateFile `
                                   -TemplateParameterFile $templateParameterFile `
                                   -ResourceGroupName $resourceGroupName `
                                   -Verbose
if($testErrors.Count -eq 0) {
    New-AzureRmResourceGroupDeployment -TemplateFile $templateFile `
                                   -TemplateParameterFile $templateParameterFile `
                                   -ResourceGroupName $resourceGroupName `
                                   -Verbose
}
else {
    $testErrors | ForEach-Object { Write-Host ($_.Message)}
}



Get-AzureRMVMImagePublisher -Location northeurope | ? { $_.PublisherName -like "netgate" }
Get-AzureRmVMImageOffer -Location northeurope -PublisherName netgate
Get-AzureRmVMImageSku -location northeurope -PublisherName netgate -Offer netgate-pfsense-azure-fw-vpn-router
Get-AzureRmMarketplaceTerms -Publisher "netgate" -Product "netgate-pfsense-azure-fw-vpn-router" -Name "netgate-pfsense-azure-243" | Set-AzureRmMarketplaceTerms -Accept

Get-AzureRMLog -CorrelationId eec18555-093d-4a2e-ac60-7152d2d5d4bf -DetailedOutput