#!/bin/bash

echo 'building...'
rm -rf dist
gleam run -m lustre/dev build app --minify

echo 'copying files...'
rm -rf built_spa
cp -r dist built_spa
mv built_spa/assets/* built_spa/
rm -r built_spa/assets

echo 'fixing links...'
sed -i '' 's|href="/app.css"|href="./app.css"|g; s|src="/app.js"|src="./app.js"|g' 'built_spa/index.html'


echo 'committing new page built...'
git add built_spa
git commit -m "build new page"


echo 'pushing to GitHub Pages...'
git subtree push --prefix built_spa origin gh-pages

echo 'Done'

