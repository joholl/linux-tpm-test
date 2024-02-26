#!/bin/sh

#set -x
set -e

[ "$KDIR" = "" ] && { echo "Variable KDIR is not set"; exit 1; }

# Make sure yq is installed:
# pip install yq

build="$(realpath build)"
rm -f $build/*.patch

# url (cannot be empty)
repo_url=$(cat linux.toml | tomlq -r '.repo.url')
# branch (default: "master")
repo_branch_arg=$(cat linux.toml | tomlq -r '"--branch=" + (.repo.branch // "master")')
# depth ("--depth=..." or empty)
repo_depth_arg=$(cat linux.toml | tomlq -r 'select(.repo.depth) | "--depth=" + (.repo.depth|tostring)')
# checkout (optional)
repo_checkout=$(cat linux.toml | tomlq -r '.repo.checkout')

echo "Checking out $repo_url"
git clone $repo_branch_arg $repo_depth_arg $repo_url $KDIR
if [ "$repo_checkout" != "null" ]; then
    git -C $KDIR checkout $repo_checkout
fi

apply_patch() {
    id=$1
    meta_url="https://patchwork.kernel.org/api/1.2/patches/$id"
    echo "Patch #$id: getting metadata from $meta_url"
    meta="$(curl --silent --location $meta_url | sed -e 's/\\/\\\\/g')"
    #name=$(echo $meta | jq -r '.name')
    mbox=$(echo $meta | jq -r '.mbox')
    echo "Patch #$id: downloading from $mbox"
    filename=$(wget --content-disposition -nv -nc -P"$build" "$mbox" 2>&1 | cut -d\" -f2)
    echo "Patch #$id: apply $filename"
    git -C $KDIR am --quiet $filename
}

apply_series() {
    id=$1
    meta_url="https://patchwork.kernel.org/api/1.2/series/$id"
    echo "Series #$id: getting metadata from $meta_url"
    meta="$(curl --silent --location $meta_url)"
    echo "$meta" | jq -cr '.patches[] | .'  | while read patch_json; do
        patch_id="$(echo $patch_json | jq -r '.id')"
        patch_mbox="$(echo $patch_json | jq -r '.mbox')"
        echo "Series #$id: patch #$patch_id: downloading from $patch_mbox"
        filename=$(wget --content-disposition -nv -nc -P"$build" "$patch_mbox" 2>&1 | cut -d\" -f2)
        echo "Series #$id: #$patch_id: apply $filename"
        git -C $KDIR am --quiet $filename
    done
}

# For each change, apply it
tomlq -c '.changes[] | .' linux.toml  | while read change; do
    kind=$(echo "$change" | jq -r '.kind')
    ids=$(echo "$change" | jq '.ids' | tr "[],\n\"" " ")
    for id in $ids; do
        case $kind in
            "patches")
                apply_patch $id
                ;;
            "series")
                apply_series $id
                ;;
            "cherry-pick")
                echo "Cherry-picking $id"
                git -C $KDIR cherry-pick --quiet $id
                ;;
            *)
                echo "Unknown kind of change: $kind"
                ;;
            esac
    done
done
