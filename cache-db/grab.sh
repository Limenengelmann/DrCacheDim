while read p; do
    fn=`echo $p | sed s,http://valid.x86.fr/,,`
    echo "$p $fn"
    curl $p > sites/$fn
    sleep 1
done <links.txt
