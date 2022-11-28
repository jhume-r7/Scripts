source ~/scripts/./cutReleaseBranch.sh
sed -i '' 's/common.version>0.0.25-SNAPSHOT/common.version>0.0.25/g' pom.xml
git add .
git commit -m "Remove snapshot common version"
git push
