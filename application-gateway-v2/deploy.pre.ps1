Add-AzureRmAccount

$subscriptionId = '935e6bd0-1a03-4fe6-8d8d-d1ecfd5a670b'
$resourceGroupName = 'rg-pre-agw-apps-1'
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

#Get-AzureRMLog -CorrelationId a090c8e4-f5a6-4d67-8507-f1a23f075931 -DetailedOutput

6ae2a166-21f8-4227-bbde-b8e85169b6ca