cd ~/Desktop/LICENTA
git checkout --orphan clean-main
git add -A                      # riscof_work e acum ignorat, nu intra
git commit -m "RV32IM core: RTL, testbench-uri, plugin RISCOF (conformitate RV32IM)"
git branch -D main
git branch -m main
git push -f origin main