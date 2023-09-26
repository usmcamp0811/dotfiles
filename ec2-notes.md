
## AWS EC2 Instance Creation Using a Local VHD

### 1. **Preparation**
- Ensure you have the VHD and `image-info.json` available.
- Setup AWS CLI and have necessary AWS credentials configured.

### 2. **S3 Bucket Creation and Configuration**
- Create an S3 bucket to upload your VHD:

  ```bash
  aws s3api create-bucket --bucket nix-image --region us-west-1 --create-bucket-configuration LocationConstraint=us-west-1
  ```

- Create a bucket policy (`bucket-policy.json`) with the following content:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "vmie.amazonaws.com"
            },
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws-us:s3:::nix-image",
                "arn:aws-us:s3:::nix-image/*"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:SourceAccount": "YOUR_ACCOUNT_ID"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws-us:iam::YOUR_ACCOUNT_ID:user/UserName1",
                    "arn:aws-us:iam::YOUR_ACCOUNT_ID:user/UserName2"
                ]
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws-us:s3:::nix-image/*"
        }
    ]
}
```

  Replace `YOUR_ACCOUNT_ID` with your AWS account ID, and `UserName1` and `UserName2` with the usernames of the IAM users who should have access.

- Apply the bucket policy:

  ```bash
  aws s3api put-bucket-policy --bucket nix-image --policy file://bucket-policy.json
  ```
### 3. **IAM Role and Policy Configuration**
- Create a `vmimport` role with a trust relationship:

  ```bash
  aws iam create-role --role-name vmimport --assume-role-policy-document file://trust-policy.json
  ```

  Where `trust-policy.json` contents are:

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": { "Service": "vmie.amazonaws.com" },
        "Action": "sts:AssumeRole",
        "Condition": {
          "StringEquals":{
            "sts:Externalid": "vmimport"
          }
        }
      }
    ]
  }
  ```

- Attach a role policy to `vmimport`:

  ```bash
  aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file://role-policy.json
  ```

  Where `role-policy.json` contents are:

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket"],
        "Resource": ["arn:aws-us:s3:::nix-image", "arn:aws-us:s3:::nix-image/*"]
      },
      {
        "Effect": "Allow",
        "Action": ["ec2:ModifySnapshotAttribute", "ec2:CopySnapshot", "ec2:RegisterImage", "ec2:Describe*"],
        "Resource": "*"
      }
    ]
  }
  ```

### 4. **Upload VHD to S3**
- Upload the VHD to the S3 bucket:

  ```bash
  aws s3 cp /path/to/your/vhd s3://nix-image/
  ```

### 5. **Import the VHD as an EC2 Image**
- Use `containers.json` to describe the location and format of the disk image:

  ```json
  [
    {
      "Description": "My server VM",
      "Format": "vhd",
      "UserBucket": {
          "S3Bucket": "nix-image",
          "S3Key": "path/to/your/vhd"
      }
    }
  ]
  ```

- Start the import:

  ```bash
  aws ec2 import-image --description "NixOS Image" --disk-containers file://containers.json
  ```

- Monitor the progress:

  ```bash
  aws ec2 describe-import-image-tasks --import-task-ids YOUR_IMPORT_TASK_ID
  ```

