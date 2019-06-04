Add-AzureRmAccount

$subscriptionId = '935e6bd0-1a03-4fe6-8d8d-d1ecfd5a670b'
$resourceGroupName = 'rg-pre-app-testapp-1'
$location = 'northeurope'
$templateFile = 'azuredeploy.json'
$templateParameterFile = 'azuredeploy.pre.parameters.json'

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
