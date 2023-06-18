
for fn in ./sites/*; do
    f=`basename $fn`
    echo $fn
    grep -A 1 "CPU Name" $fn
done
