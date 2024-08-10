title: Azure CLI setup of SPN to Create Subscriptions
date: 2024-08-10
css: style.css
tags: azure


## Azure CLI setup of SPN to Create Subscriptions

[Microsoft documents](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure-with-service-principle) how to authenticate Terraform to Azure using a SPN (Service Principal Name) identity. To do anything useful with that SPN, you will need to give it rights on the subscriptions it will be used to manage.

You may want Terraform to be able to create new subscriptions when running as your SPN. If you are using Enterprise Agreement billing, this is a little tricky since SPNs cannot create subscriptions under an EA account unless the SPN has been granted a Subscription Creator role which can only be granted via an Azure REST call.

Below is a script for doing that using CLI only. It assumes you already have a SPN and know its Client ID, as well as identifier numbers about your EA billing account that you can find in the Azure web UI. None of these values change, so as part of setup, you can find them and record them for use in scripts.

I developed this based on Microsoft docs [here](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals#assign-the-subscription-creator-role-to-the-spn) and [here](https://learn.microsoft.com/en-us/rest/api/billing/role-assignments/put?view=rest-billing-2019-10-01-preview&tabs=HTTP) and a Stack Overflow answer [here](https://stackoverflow.com/questions/56645576/activation-of-service-principal-as-account-owner-in-the-ea-portal-via-powershell).

Script below is for Enterprise Agreement billing only. If you are using "Credit Card" type billing it won't work for you.

```
#!/bin/bash

set -euxo pipefail
which uuidgen # will exit due to set -e if no uuidgen, which is part of util-linux
which az

# Terraform reads these variable names to auth as SPN
# Client ID is printed out when you create your SPN
# Tenant ID is global to your tenant
# You must set these for this script to work
ARM_TENANT_ID=a-uuid-goes-here
ARM_CLIENT_ID=a-uuid-goes-here

# Info about your Enterprise Agreement billing/enrollment
# You must set these for this script to work
billingAccountName=an-integer-goes-here
enrollmentAccountName=an-integer-goes-here

# Role definition id is documented by Microsoft
# Role assignment name is randomly generated
roleDefinitionId=a0bcee42-bf30-4d1b-926a-48d21664ef71 #subscriptionCreator
billingRoleAssignmentName=$(uuidgen)

# Get the SPN's Object ID using the SPN's Client ID
SPN_ObjectID=$(az ad sp show --id ${ARM_CLIENT_ID?} --query id --output tsv)


t=$(mktemp)
cat <<HERE >$t
{
  "properties": {
     "principalID": "${SPN_ObjectID}",
     "principalTenantId": "${ARM_TENANT_ID}", 
     "roleDefinitionId": "/providers/Microsoft.Billing/billingAccounts/${billingAccountName}/enrollmentAccounts/${enrollmentAccountName}/billingRoleDefinitions/${roleDefinitionId}"
  }
}
HERE

az rest --method put --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/${billingAccountName}/enrollmentAccounts/${enrollmentAccountName}/billingRoleAssignments/${billingRoleAssignmentName}?api-version=2019-10-01-preview" --body @${t}
```
