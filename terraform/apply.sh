if [ "$#" -eq 1 ]; then
    echo "USING PRESENT file $1"
    terraform apply "$1" # use given plan file
else
    terraform apply # create plan and immediately apply
fi

KEY_FILE="id_rsa"
terraform output admin_private_key > "$id_rsa"
chmod 600 "$id_rsa"

IP_ADDRESS=$(terraform output publicip)
USERNAME="azure"
ssh -i "$KEY_FILE" "${username}@${IP_ADDRESS}"