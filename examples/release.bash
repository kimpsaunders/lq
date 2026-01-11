#!/bin/bash

for root in /opt /private/tmp
do
  [ -w $root ] && break
done

root_apps=$root/application
root_envs=$root/environment
root_vols=$root/volume

resolve="realpath -s" ## make symlink targets absolute
#resolve="echo"        ## ... don't
ss=/*

for var in root_{app,env,vol}s
do
  echo -n ${!var} > $var.txt
done

rm -rf $root_vols $root_apps $root_envs

for candidate in /usr/bin/{sha,md5}sum
do
  [ -x $candidate ] && sum=$candidate
done


## write the hello scripts and create volume directories
for i in {1..5}
do
  version=1.$i
  year=201$i
  month=0$i
  day=0$i

  cat > hello <<END
#!/bin/bash

echo Hello world!
echo Version $version Copyright $year
echo Released ${year}-${month}-${day}

END
  seq -f '# %020g' $i >> hello

  chmod +x hello
  digest=`$sum hello | cut -c1-8`
  dir=$root_vols/volume$i$i$i$i/$digest
  bin=$dir/bin
  mkdir -p $bin
  mv hello $bin
  echo "${year}-${month}-${day}: released version $version." > $dir/CHANGELOG
  touch -t 201${i}0${i}0${i}0${i}0${i} $root_vols/volume$i$i$i$i $dir $bin $bin/hello $dir/CHANGELOG
done

## create application symlinks

root_apps_helloworld=$root_apps/helloworld/version
mkdir -p $root_apps_helloworld

(
  cd $root_apps_helloworld
  for dir in ../../../volume/*/*
  do
    hello=$dir/bin/hello
    version=`$hello | grep Version | cut -d' ' -f2`
    ln -s `$resolve $dir` $root_apps_helloworld/$version
    touch -h -m -r $hello $root_apps_helloworld/$version
  done
)

development=1.5
testing=1.3
production=1.1

mkdir -p $root_envs/{development,testing,production}

(
  for directory in $root_envs/*
  do
    cd $directory
    environment=`basename $directory`
    version=`$resolve ../../application/helloworld/version/${!environment}`
    ln -s $version $directory/helloworld
    touch -h -m -r $version $directory/helloworld
  done
)

PATH=$PATH:`pwd`/..

cat > release-01-opt.sh <<EOF
ls -flogd $root_envs$ss$ss $root_apps_helloworld$ss $root_vols$ss$ss
EOF

cat > release-01-volume.sh <<EOF
ls -flogd $root_apps_helloworld/1.3
EOF

cat > release-01-production.sh <<END
ls -flogd $root_envs/production/helloworld
END

set -x

hello=$root_envs/production/helloworld/bin/hello
one="lq $hello"

echo -n $hello > production_hello.txt

{
  lq $hello
  $hello
} 2>&1 | tee hello.txt

cat > release-02-production.sh <<END 
# check the initial production version
lq $hello
cd $root_envs/production
# take a copy of the symlink from testing/
cp -P ../testing/helloworld helloworld_tmp
# overwrite the helloworld symlink
mv -T helloworld_tmp helloworld  
# check the final production version
lq $hello
END

old=volume3333
new=volume5555
dir=`basename $root_vols/$old/*`

for var in dir old new
do
  echo -n ${!var} > volume_$var.txt
done

## volume move

cat > release-03-volume.sh <<END
# check the initial storage volume location
lq $hello
# copy $dir to $new
cp -ar $root_vols/$old/$dir $root_vols/$new
cd $root_apps_helloworld
# create a symblink with the new target
ln -s `cd $root_apps_helloworld; $resolve ../../../volume/$new/$dir` 1.3_tmp
# overwrite the old 1.3 symlink
mv -T 1.3_tmp 1.3
# check the final storage volume location
lq $hello
END

## garbage collection


cat > release-04-gcapp.sh <<END
# prepare a sorted, unique list of $root_envs symlink targets as app1.txt
readlink $root_envs$ss$ss | sort | uniq | tee /tmp/app1.txt
# prepare a sorted, unique list of $root_apps symlinks as app2.txt
ls -d $root_apps$ss$ss$ss | sort | tee /tmp/app2.txt
# delete everything in app2.txt and not in app1.txt
comm -1 -3 /tmp/app{1,2}.txt | xargs -t rm 
END

cat > release-05-gcvol.sh <<END
# prepare a sorted, unique list of $root_apps symlink targets as vol1.txt
readlink $root_apps/*/*/* | sort | uniq > /tmp/vol1.txt
# prepare a list of $root_vols directories as vol2.txt
ls -d $root_vols/*/* | sort | uniq > /tmp/vol2.txt
# delete directories in vol2.txt and not in vol1.txt
comm -1 -3 /tmp/vol{1,2}.txt | xargs -t rm -rf
END

## attributes

cat > release-06-attrs.sh <<END
lq -a environment/application/version -d': ' -e $root_envs/*/*
END
