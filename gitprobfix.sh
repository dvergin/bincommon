echo Assuming something failed when you pushed.
echo 
echo 1) Making sure you have the latest remote tip locally
git fetch origin

echo 2) Moving HEAD back to the remote tip, but keeping all local files as they were
git reset --mixed origin/main
# (equivalently: git reset origin/main)

echo 3) Now you’re back to a clean slate: no pending commits.
echo Fix the problem and then proceed to add, commit, and push as needed.
