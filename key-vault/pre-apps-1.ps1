Add-AzureRmAccount

$subscriptionId = 'dbded607-ae20-4546-847d-eda290fc3703'
$resourceGroupName = 'rg-pre-kv-apps-1'
$location = 'northeurope'
$templateFile = 'azuredeploy.json'
$templateParameterFile = 'azuredeploy.pre-apps-1.parameters.json'

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
