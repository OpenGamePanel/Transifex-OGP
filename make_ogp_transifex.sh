#!/bin/bash
# Author:  own3mall <own3mall@gmail.com>
# About:  Script that pulls the transifex files, puts them in the OGP stucture, copies the structure to the website and every module folder, runs a git pull, git clean, git commit, git push to remote repositories :D
# Optional parameter ($1) is any new language to add

######################
#   IMPORTANT VARS   #
######################

transifexUser="{YOUR_TRANSIFEX_USER_HERE}"
transifexPass="{YOUR_TRANSIFEX_PASS_HERE}"
linuxUser="{YOUR_LINUX_USERNAME_HERE}"

######################
#  FUNCTIONS #########
######################
function setGlobalVars(){
	# $1 is new languages string to add
	# $2 is new language short code to add
	# Variables
	transifexDir="/home/${linuxUser}/transifex"
	gitDir="/home/${linuxUser}/github"
	currentRunDate=$(date "+%m_%d_%Y_%H-%M-%S-%p")
	logFile="/home/${linuxUser}/transifex/logFile_${currentRunDate}"
	gitPath="/usr/bin/git"
	BaseLang="English"
	LangFolder="lang"
	ClearLogFilesOlderThanDays=20
	debug=true
	LANGToAdd="$1"
	LANGToAddCode="$2"
	LANGCodesFile="/home/${linuxUser}/langCodes"
	
	# Adjust log file to contain new language in file name to distinguish the log file types
	if [ ! -z "$LANGToAdd" ] && [ ! -z "$LANGToAddCode" ]; then
		logFile="${logFile}_new_LANG_${LANGToAdd}_${LANGToAddCode}"
	fi
	
	# Create the log file
	> "${logFile}"
	
	# Save new language mappings to a file
	WriteNewLanguageCodeAndStrIfNeeded
	
	# Load our saved language mappings
	if [ -e "$LANGCodesFile" ]; then
		source "$LANGCodesFile"
	fi
}

function WriteNewLanguageCodeAndStrIfNeeded(){
	if [ ! -z "$LANGToAdd" ] && [ ! -z "$LANGToAddCode" ]; then
		# add it to our map file
		# example: ar=Arabic
		# Then source file and we have variables and values
		if [ ! -e "$LANGCodesFile" ]; then
			touch "$LANGCodesFile"
		fi
		
		contents=$(cat "$LANGCodesFile")
		hasLangCode=$(echo "$contents" | grep -o "${LANGToAddCode}=")
		if [ -z "$hasLangCode" ]; then
			echo "${LANGToAddCode}='${LANGToAdd}'" >> "$LANGCodesFile"
		fi
	fi
}

function clearLogFilesOlderThan(){
	find "$transifexDir" -mindepth 1 -type f -name "logFile*" -mtime +${ClearLogFilesOlderThanDays} -delete
}

function copyFile(){
	mkdir -p "../${langPath}/modules"
	if [ "$OGPFileNamePRE" != "global" ] && [ "$OGPFileNamePRE" != "install" ]; then
		cp "$f" "../${langPath}/modules/${OGPFileNamePHP}"
	else
		cp "$f" "../${langPath}/${OGPFileNamePHP}"
	fi
}

function getTranslations(){
	cd "$transifexDir"
	rm -rf ".tx"
	rm -rf translations
	/usr/local/bin/tx init --host="https://www.transifex.com" --user="${transifexUser}" --pass="${transifexPass}"
	/usr/local/bin/tx set --auto-remote https://www.transifex.com/opengamepanel/ogp
	/usr/local/bin/tx pull -a -s
	if [ ! -d "translations" ]; then
		logMessage "Failed to retrieve translation files."
		exit
	fi
	rm -rf staging
	mkdir -p staging
	cp -r translations/* staging
}

function makeOGPStructure(){
	cd "$transifexDir"
	cd staging
	
	for folder in `find ./* -type d`; do
		# https://stackoverflow.com/questions/20348097/bash-extract-string-before-a-colon
		# IN THIS CASE, EXTRACT STRING BEFORE ENDING "php"
		OGPFileNamePRE=$(cut -d "." -f 3 <<< "$folder" | sed 's/php$//')
		OGPFileNamePHP="${OGPFileNamePRE}.php"

		# Logging
		logMessage "Current translation folder is $folder"
		logMessage "OGP module name is $OGPFileNamePRE"
		logMessage "OGP full language file name is $OGPFileNamePHP"

		if [ -e "$folder" ]; then
			cd "$folder"
			for f in `find ./* -type f | sed "s|^\./||"`; do
				cpyFile=true
				langPath=
				case "$f" in
					"en.php")
						langPath="lang/English"
						;;
					"da.php")
						langPath="lang/Danish"
						;;
					"de.php")
						langPath="lang/German"
                        ;;
					"es.php")
						langPath="lang/Spanish"
                        ;;
					"fr.php")
						langPath="lang/French"
						;;
					"hu.php")
						langPath="lang/Hungarian"
						;;
					"pl.php")
						langPath="lang/Polish"
						;;
					"pt.php")
						langPath="lang/Portuguese"
						;;
					"ru.php")
						langPath="lang/Russian"
						;;
					"it.php")
						langPath="lang/Italian"
						;;
					"ar.php")
						langPath="lang/Arabic"
						;;
					"${LANGToAddCode}.php")
						langPath="lang/${LANGToAdd}"
						;;
					*)
						# Check and see if it's defined in our lang code file
						fileNameLangCode="$(returnUntilLastMatch "$f" ".")"
						if [ ! -z "${!fileNameLangCode}" ]; then
							langPath="lang/${!fileNameLangCode}"
						else
							cpyFile=false
						fi
						;;
				esac
				
				# copy the files over if needed based on language
				if [ "$cpyFile" = true ] && [ ! -z "$langPath" ]; then
					copyFile
				fi
				
			done
			cd ..
		fi
	done
}

function returnUntilLastMatch(){
	# $1 = string
	# $2 = character
	echo "${1%${2}*}"
}

function logMessage(){
	if [ ! -z "$1" ]; then
		echo -e "$1" >> "$logFile"
		if [ "$debug" = true ]; then
			echo -e "$1"
		fi
	fi
}

function copyOGPStructureToAllGitRepos(){
	cd "$transifexDir/staging"
	if [ -d "lang" ] && [ -e "lang" ]; then
		# Loop through git folders
		for folder in `find "${gitDir}" -mindepth 1 -maxdepth 1 -type d`; do
			logMessage "Current github folder is $folder"
			cd "$folder"
			pWD=$(pwd)
                        
			# Get latest files from GitHub repo
			"$gitPath" pull
			
			# Clean non-versioned files (in case there's some already in here that should no longer be here)
			# https://stackoverflow.com/questions/5879932/git-clean-not-working-recursively (added -d flag0
			"$gitPath" clean -df
                        
			# Search for existing files within the BaseLang folder so we know how to handle
			# any possible new language files once we copy the mess of all module language files into this directory
			found=$(find ${LangFolder}/${BaseLang} -type f | sed -e "s,^${LangFolder}/${BaseLang}/,,";)
                        
			# Copy our bundled language files which includes languages for everything in this repo / module
			cp -rf "$transifexDir/staging/lang" "$folder"
			addOtherLanguagesToBaseLangFilesIfNotVersioned "$folder" "$found"
                        
			# Handle adding new language files if any to the repo
			if [ ! -z "${found}" ]; then
				logMessage "Found this list of files that exist in the base master language of ${BaseLang} for this git repository (${pWD}):"
				logMessage "${found}"
				handleNewLanguages "${found}"
			fi
                        
			# Clean non-versioned files (those not under source control via the Git repo) and commit changes
			"$gitPath" clean -df
			"$gitPath" commit -am "Transifex Language Updates - Generated by own3mall's auto script."
			"$gitPath" push
		done
	fi
}

function handleNewLanguages(){
	if [ ! -z "$LANGToAdd" ] && [ ! -z "$1" ]; then
		logMessage "We have new languages to add!"
		for var in "${LANGToAdd[@]}"
		do
			for i in `echo -e ${1}`
			do
				if [ -e "${LangFolder}/${var}/${i}" ]; then
					logMessage "Adding file ${LangFolder}/${var}/${i} to GitHub repo ${pWD}!"
					"$gitPath" add "${LangFolder}/${var}/${i}"
				else
					logMessage "File ${i} not found in ${LangFolder}/${var} for GitHub repo ${pWD}!  Skipping..."
				fi
			done
		done
	else
		logMessage "No languages need to be added."
	fi
}

function addOtherLanguagesToBaseLangFilesIfNotVersioned(){
	# $1 is the github directory foler
	# $2 is the list of found files
	for i in `echo -e ${2}`
	do
		for folder in `find "${1}/${LangFolder}" -mindepth 1 -maxdepth 1 -type d`; do
			if [ -e "${folder}/${i}" ]; then
				versioned=$("$gitPath" ls-files "${folder}/${i}")
				if [ -z "$versioned" ]; then
					logMessage "File ${folder}/${i} is not versioned. Adding it now..."
					"$gitPath" add "${folder}/${i}"
				fi
			fi 
		done
	done
}
######################
#  Main ##############
######################
setGlobalVars "$1" "$2"
clearLogFilesOlderThan
getTranslations
makeOGPStructure
copyOGPStructureToAllGitRepos
