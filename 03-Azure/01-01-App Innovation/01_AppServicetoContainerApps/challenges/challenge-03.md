# Challenge 3 - Create the Container App

[Previous Challenge Solution](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-04.md)

## Goal

Now that you have a deployable container image, you can setup the Container App to host you web app. As described above, you will use the Container Apps because it is a simple, scalable and straight-forward service that is perfectly suitable for this use case. However, the container image is highly portable and could be deployed into other container services as well.

## Actions

* Create an Azure Container App and the Environment
* Automate the deployment with GitHub Actions
* Make a change and deploy it

Hint: Use this workflow task to get the latest container image tag from the registry. You can insert the task after the login to Azure and then use the variable `image_tag`:

    - name: Get Latest Container Image Tag
      id: get_tag
      run: |
        TAG=$(az acr repository show-tags --name microhackregistry --repository microhackapp --orderby time_desc --output tsv --detail | head -n 1 | awk '{print $4}')
        NUMERIC_TAG=$(echo "$TAG" | grep -oE '[0-9]+')
        INCREMENTED_TAG=$((NUMERIC_TAG + 1))
        UPDATED_TAG=$(echo "$TAG" | sed "s/$NUMERIC_TAG/$INCREMENTED_TAG/")
        echo "image_tag=$UPDATED_TAG" >> $GITHUB_OUTPUT

## Success Criteria

* You successfully deployed the container image to the Container App
* You can access the newly hosted web app
* You can make changes to the web app and deploy them into the Container App

## Learning resources

* [Creating an Azure Container App](https://learn.microsoft.com/en-us/azure/container-apps/quickstart-portal)
* [Connection Azure and GitHub (use option 2)](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)
* [Deploying Azure Container Apps with GitHub 1](https://learn.microsoft.com/en-us/azure/container-apps/github-actions)
* [Deploying Azure Container Apps with GitHub 2](https://github.com/Azure/container-apps-deploy-action)

