#!/bin/bash
############
# Series of functions used to build AKS Linux 
# Main program calls these functions at the bottom of this script.
# Note that the signature files for the AzureCli for Microsoft are not added here since a repo is not being used.
##############

#Set a base directory
USER="$(whoami)"
HOMEDIR="/home/$USER"
rm -f "$HOMEDIR"/install.log


#####################
# install kubectl
# Usage: Install kubectl
#	install_kubectl 
######################
function install_kubectl() {
	kubectl_checksum=$(echo "$(cat "$HOMEDIR/installfiles/linuxKubectl/checksum/kubectl.sha256")  $HOMEDIR/installfiles/linuxKubectl/binaries/kubectl" | sha256sum --check | cut -d/ -f7)
		if [ "$kubectl_checksum" = "kubectl: OK" ]; then
			echo "Installing kubectl" | tee -a "$HOMEDIR"/install.log
			sudo install -o root -g root -m 0755 "$HOMEDIR"/installfiles/linuxKubectl/binaries/kubectl /usr/local/bin/kubectl | tee -a "$HOMEDIR"/install.log
			verify_kubectl_install=$(kubectl version --short) 
			if echo "$verify_kubectl_install" | grep Client | grep -v grep; then
				echo "Kubectl successfully installed" | tee -a "$HOMEDIR"/install.log
			else
				echo "Kubectl install failed." >&2	| tee -a "$HOMEDIR"/install.log	
				exit 1		
			fi 
		else
			echo "Checksum for kubectl does not match.  Kubectl was not installed." >&2 | tee -a "$HOMEDIR"/install.log
			exit 1
		fi
	}

#########################
# install Azure CLI
# Usage: Install Azure CLI from rpm or debian.  Determines whether installing on Ubuntu or RHEL
# 	install_azurecli
#########################
function install_azurecli() {
#Install Ubuntu debian
	if grep ID=ubuntu /etc/os-release| grep -v grep; then
	azFile="$(find "$HOMEDIR"/installfiles/Ubuntu -type f -name '*azure-cli*' | cut -d/ -f6)"
		if [ -e "$HOMEDIR"/installfiles/Ubuntu/"$azFile" ]; then
			echo "Installing azure cli"
			sudo dpkg -i "$HOMEDIR"/installfiles/Ubuntu/"$azFile" | tee -a "$HOMEDIR"/install.log
			if az version | grep azure-cli | grep -v grep; then 
				echo "Azure ClI Successfully installed on Ubuntu." | tee -a "$HOMEDIR"/install.log
			else 
				echo "Azure CLI install failed on Ubuntu." >&2 | tee -a "$HOMEDIR"/install.log
				exit 1
			fi
		else 
			echo "Azure CLI file does not exist on this server.  Please assure the file is in the azureuser home directory and rerun the function." >&2 | tee -a "$HOMEDIR"/install.log
			exit 1
		fi
	fi
	#Install RHEL rpm
	if [ -e /etc/redhat-release ]; then
	azFile="$(find "$HOMEDIR"/installfiles/RHEL -type f -name '*azure-cli*' | cut -d/ -f6)"
		if [ -e "$HOMEDIR"/installfiles/RHEL/"$azFile" ]; then
			echo "Installing azure cli"
			sudo rpm -ivh --nodeps "$HOMEDIR"/installfiles/RHEL/"$azFile" | tee -a "$HOMEDIR"/install.log
				if az version | grep azure-cli | grep -v grep; then 
					echo "Azure ClI Successfully installed on RHEL." | tee -a "$HOMEDIR"/install.log
				else 
					echo "Azure CLI install failed on RHEL." >&2 | tee -a "$HOMEDIR"/install.log
					exit 1
				fi
		else 
			echo "Azure CLI file does not exist on this server.  Please assure the file is in the azureuser home directory and rerun the function." >&2 | tee -a "$HOMEDIR"/install.log
			exit 1
		fi
	fi
}

#################################
# install Helm
# Usage: Function to install helm if checksums and tar signature match
# Note that the find commands are being used here to handle multiple versions
#	install_helm 
#################################
function install_helm() {
	HelmDir="installfiles/linuxHelm"
	ShaFile=$(find "$HOMEDIR/$HelmDir" -type f -name '*helm*[sha256sum]' | cut -d/ -f6)
	Sha=$(cat "$HOMEDIR/$HelmDir/$ShaFile" | awk '{ print $1 }')
	Tar=$(find "$HOMEDIR/$HelmDir" -type f -name '*helm*[^sha256sum]*.tar.gz' | cut -d/ -f6)
	FileSha=$(openssl sha1 -sha256 "$HOMEDIR/$HelmDir/$Tar" | awk '{print $2}')
	asc=$(find "$HOMEDIR/$HelmDir" -type f -name '*helm*[^sha256sum]*.tar.gz.asc' | cut -d/ -f6)

	#Verify Signature of tar file 
	if [ -e "$HOMEDIR/$HelmDir/$Tar" ]; then
		gpg --import "$HOMEDIR/$HelmDir/helm_key_signature" | tee -a "$HOMEDIR"/install.log
		if ! gpg --verify "$HOMEDIR/$HelmDir/$asc" 2>&1 | grep "Good signature"; then 
		echo "The signature for the tar file is not a good signature." >&2 | tee -a "$HOMEDIR"/install.log
		exit 1
		fi
	else
		echo "The tar file does not exist so the signature can not be verified." >&2 | tee -a "$HOMEDIR"/install.log
		exit 1
	fi
	#Checksums match
	if [ "$HOMEDIR/$HelmDir/$Sha" = "$HOMEDIR/$HelmDir/$FileSha" ]; then 
	#Install Helm 
		sudo tar -zxvf "$HOMEDIR/$HelmDir/$Tar" 
		sudo cp "$HOMEDIR/installfiles/linuxScripts/linux-amd64/helm" /usr/local/bin/helm | tee -a "$HOMEDIR/install.log"
		sudo chown root:root /usr/local/bin/helm | tee -a "$HOMEDIR/install.log" 
		#Verify it installed
		if [ -e /usr/local/bin/helm ]; then 
			echo "Helm installed correctly" | tee -a "$HOMEDIR"/install.log
		else
			echo "Helm did not install properly. Exiting script." >&2 | tee -a "$HOMEDIR"/install.log
			exit 1
		fi
	else
		echo "Checksums do not match. Exiting script." >&2 | tee -a "$HOMEDIR"/install.log
		exit 1
	fi
}

############################
# Install AKSEngine
# Usage: mv executable and set permissions
# 	install_aksengine
# This is an interactive script and requires input from a user.
#############################
install_aksengine() {
	ans=''
	while [ -z "$ans" ]; do
		read -p "Please enter the version you would like installed in the following example format v0.70.0: " ans
	done
	if [ -e "$HOMEDIR/installfiles/aks-engine-$ans-linux-amd64/aks-engine" ]; then
	sudo cp "$HOMEDIR/installfiles/aks-engine-$ans-linux-amd64/aks-engine" /usr/local/bin | tee -a "$HOMEDIR"/install.log
	sudo chmod 0755 /usr/local/bin/aks-engine
	verify_AKSEngine_install=$(aks-engine version | grep Version | awk '{ print $1}')
		if [ "$verify_AKSEngine_install" = "Version:" ]; then 
			echo "$(aks-engine version | grep Version) installed successfully"
		else
			echo "AKS engine install failed.  Please verify the file exists and the version was passed in." >&2 | tee -a "$HOMEDIR"/install.log
			exit 1
		fi
	else 
		echo "The aks-engine file does not exist in the aks-engine install folder.  Install failed." >&2 | tee -a "$HOMEDIR"/install.log
		exit 1
	fi 
}

##################################
# add certificates 
# Usage: Add certificate to the trust to either Ubuntu or Rhel Server
#  add_cert
# This is an interactive script and requires input from a user.
###################################

add_cert() {
	pem=''
	while [ -z "$pem" ]; do
		read -r -p "Please enter the name of the pem file to install? Please answer in this example format: cert.pem For an asdk deployment please answer asdk." pem
	done
	case $pem in
	asdk) sudo cp /var/lib/waagent/Certificates.pem /usr/local/share/ca-certificates/azurestackca.crt; sudo update-ca-certificates ;;
	*) 
		if grep ID=ubuntu /etc/os-release| grep -v grep; then
		 	if [ -e "$HOMEDIR"/installfiles/"$pem" ]; then
				echo "Installing certificates on Ubuntu..."
				sudo cp "$HOMEDIR"/installfiles/"$pem" /usr/local/share/ca-certificates/azurestackca.crt
				sudo update-ca-certificates | tee -a "$HOMEDIR"/install.log 
			fi
		fi
		if [ -e /etc/redhat-release ]; then
			if [ -e "$HOMEDIR"/installfiles/"$pem" ]; then
				echo "Installing certificates on RHEL..."
				sudo cp "$HOMEDIR"/installfiles/"$pem" /usr/share/pki/ca-trust-source/anchors
				sudo update-ca-trust extract | tee -a "$HOMEDIR"/install.log
			fi
	fi 
	esac 
}

###################################
# cleanup files
# Usage: Clean up files used during intalls
# 	cleanup 
###################################
cleanup() {
rm -Rf "$HOMEDIR"/installfiles
}

#############################################
# keyvault add secret
# Usage: Adds a new secret to a keyvault. File secrets that do not include an encoding parameter are defaulted to utf-8
# 	keyvault_add_secret
#Usage examples:
# File no encoding set: keyvault_add_secret file filetest2 kvtestemc private-network-defined-cluster.json
# File encoding set: keyvault_add_secret file filetest2 kvtestemc private-network-defined-cluster.json utf-8
# Value secret: kevault_add_secret value test1 kvtestemc testvalue
##############################################
keyvault_add_secret(){
	type=$1;
	secretName=$2;
	vaultName=$3;
accountName=$(az account show --query name)
if [ -z "$accountName" ]; then
echo "You are not logged into an azure tenant.  Please login and rerun the function."
fi
case $type in
	"value") 
		value=$4;
		if [ -z "$value" ]; then
			echo "A paramter was not passed to the function.  Please restart the function with the approriate values." >&2 | tee -a "$HOMEDIR"/install.log 
		else
			echo "Adding \"$value\" to \"$vaultName\"" >&2 | tee -a "$HOMEDIR"/install.log 
			az keyvault secret set --name "$secretName" --vault-name "$vaultName" --value "$value" >&2 | tee -a "$HOMEDIR"/install.log 
		fi ;;
	"file") 
		fileLocation=$4; 
		if [ -z "$fileLocation" ]; then 
			echo "A paramter was not passed to the function.  Please restart the function with the approriate values." >&2 | tee -a "$HOMEDIR"/install.log 
		else 
			encoding=$5;
			if [ -z "$encoding" ]; then 
			encoding="utf-8"
			fi 
			echo "Adding \"$fileLocation\" to \"$vaultName\"" >&2 | tee -a "$HOMEDIR"/install.log 
			az keyvault secret set --name "$secretName" --vault-name "$vaultName" --file "$fileLocation" --encoding "$encoding" >&2 | tee -a "$HOMEDIR"/install.log 
		fi ;;
	*) echo "An invalid parameter has been passed to the function.  Please pass either a file path or a value for the secret."	
esac 
}
