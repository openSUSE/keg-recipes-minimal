# Add products repos before having registration process
# using $basearch; $arch refers to x86_64_v2
echo 'Adding $basearch repos to ALP Micro'
zypper addrepo --refresh --name 'ALP Micro 1.0 Repository' 'https://updates.suse.com/SUSE/Products/ALP-Micro/1.0/$basearch/product/' 'ALP-Micro-1.0'
