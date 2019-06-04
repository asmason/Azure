Add-AzureRmAccount

$subscriptionId = '7fbd9490-0f9e-4bb5-a0c4-7d3ee2d88ba7'
$resourceGroupName = 'rg-prd-kv-hub-1'
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
