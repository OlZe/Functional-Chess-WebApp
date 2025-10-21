#!/bin/bash

echo 'building...'
rm -rf dist
gleam run -m lustre/dev build app --minify

echo 'preparing output dir...'
rm -rf built_spa
cp -r dist built_spa
mv built_spa/assets/* built_spa/
rm -r built_spa/assets

echo 'pushing to GitHub Pages...'
git subtree push --prefix built_spa origin gh-pages

echo 'Done'

