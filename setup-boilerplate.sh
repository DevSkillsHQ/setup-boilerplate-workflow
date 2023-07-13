#!/bin/bash

branch_name=$1
boilerplate=$2

git clone https://github.com/DevSkillsHQ/$boilerplate.git

# Parse "build" and "start" scripts from the boilerplate's package.json and write it to a new JSON file
jq '{scripts: {build: .scripts.build, start: .scripts.start}}' $boilerplate/package.json > scripts.json

# Merge the existing package.json with the scripts.json
jq -s '.[0] * .[1]' package.json scripts.json > package.tmp.json && mv package.tmp.json package.json

# Remove the temporary scripts.json file
rm scripts.json

cp -r $boilerplate/app* .

# Fetch apiUrl from cypress.json or cypress.config.js
if [ -f "$boilerplate/cypress.json" ]; then
  apiUrl=$(jq -r '.env.apiUrl' $boilerplate/cypress.json)
elif [ -f "$boilerplate/cypress.config.js" ]; then
  apiUrl=$(node -e "\
    const fs = require('fs');\
    const fileContent = fs.readFileSync('./$boilerplate/cypress.config.js', 'utf-8');\
    const match = fileContent.match(/apiUrl:\\s?'([^']*)'/);\
    if (match) console.log(match[1]);\
  ")
else
  echo "Neither cypress.json nor cypress.config.js was found in the $boilerplate directory"
  exit 1
fi

# Set apiUrl in cypress.json or cypress.config.js of the current directory
if [ -f "cypress.json" ]; then
  jq ".env.apiUrl |= \"$apiUrl\"" cypress.json > cypress.temp.json && mv cypress.temp.json cypress.json
elif [ -f "cypress.config.js" ]; then
  node -e "\
    const fs = require('fs');\
    let fileContent = fs.readFileSync('./cypress.config.js', 'utf-8');\
    fileContent = fileContent.replace(/(apiUrl:\\s?')[^']*'/, `apiUrl: '${apiUrl}'`);\
    fs.writeFileSync('./cypress.config.js', fileContent);\
  "
else
  echo "Neither cypress.json nor cypress.config.js was found in the current directory"
  exit 1
fi

git add cypress.*

rm -rf $boilerplate
npm i
git add package.json app*

git config --global user.email "setup-boilerplate@example.com"
git config --global user.name "Setup boilerplate"
git commit -m "Initialize boilerplate $boilerplate"
git push origin $branch_name
