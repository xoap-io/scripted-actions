
az resource delete \
    --resource-group $sigResourceGroup \
    --resource-type Microsoft.VirtualMachineImages/imageTemplates \
    -n helloImageTemplateforSIG01

az role assignment delete \
    --assignee $imgBuilderCliId \
    --role "$imageRoleDefName" \
    --scope /subscriptions/$subscriptionID/resourceGroups/$sigResourceGroup

az role definition delete --name "$imageRoleDefName"

az identity delete --ids $imgBuilderId

sigDefImgVersion=$(az sig image-version list \
	-g $sigResourceGroup \
	--gallery-name $sigName \
	--gallery-image-definition $imageDefName \
	--subscription $subscriptionID --query [].'name' -o json | grep 0. | tr -d '"')
	az sig image-version delete \
	-g $sigResourceGroup \
	--gallery-image-version $sigDefImgVersion \
	--gallery-name $sigName \
	--gallery-image-definition $imageDefName \
	--subscription $subscriptionID

az sig image-definition delete \
	-g $sigResourceGroup \
	--gallery-name $sigName \
	--gallery-image-definition $imageDefName \
	--subscription $subscriptionID

az sig delete -r $sigName -g $sigResourceGroup

az group delete -n $sigResourceGroup -y
