# File Sharing Smart Contract

## Overview

This smart contract implements a decentralized file sharing system on the Stacks blockchain. It allows users to upload, update, and share files with granular access control and version history.

## Features

- File upload and storage
- File metadata management
- Version control for files
- Access control with expiration
- User storage statistics
- File tagging and search functionality

## Setup

To use this smart contract, you need to have a Stacks wallet and some STX tokens for transaction fees.

1. Deploy the contract to the Stacks blockchain using Clarinet or the Stacks Explorer.
2. Once deployed, you can interact with the contract using its various functions.

## Contract Functions

### Public Functions

#### \`upload-new-file\`

Uploads a new file to the system.

Parameters:
- \`file-name\`: (string-ascii 64) Name of the file
- \`file-hash\`: (string-ascii 64) Hash of the file content
- \`file-size\`: (uint) Size of the file in bytes
- \`file-type\`: (string-ascii 32) Type of the file
- \`file-description\`: (string-ascii 256) Description of the file
- \`is-private\`: (bool) Whether the file is private
- \`is-encrypted\`: (bool) Whether the file is encrypted
- \`file-tags\`: (list 10 (string-ascii 32)) List of tags associated with the file

Returns: (ok uint) The ID of the newly uploaded file

#### \`update-existing-file\`

Updates an existing file with new content.

Parameters:
- \`file-id\`: (uint) ID of the file to update
- \`new-file-hash\`: (string-ascii 64) New hash of the file content
- \`new-file-size\`: (uint) New size of the file in bytes
- \`change-description\`: (string-ascii 256) Description of the changes made

Returns: (ok uint) The new version number of the file

#### \`grant-file-access-with-expiry\`

Grants access to a file for a specific user, with optional expiration.

Parameters:
- \`file-id\`: (uint) ID of the file
- \`user\`: (principal) Principal of the user to grant access
- \`allow-edit\`: (bool) Whether to allow editing
- \`expiration-time\`: (optional uint) Optional expiration time for the access

Returns: (ok bool) True if access was granted successfully

#### \`update-file-metadata\`

Updates the metadata of an existing file.

Parameters:
- \`file-id\`: (uint) ID of the file
- \`new-file-name\`: (optional (string-ascii 64)) New name for the file
- \`new-file-description\`: (optional (string-ascii 256)) New description for the file
- \`new-file-tags\`: (optional (list 10 (string-ascii 32))) New list of tags for the file

Returns: (ok bool) True if metadata was updated successfully

### Read-Only Functions

#### \`get-file-version-history\`

Retrieves the version history of a file.

Parameters:
- \`file-id\`: (uint) ID of the file

Returns: (ok (optional {file-hash: (string-ascii 64), file-size: uint, modified-by-user: principal, modification-timestamp: uint, change-description: (string-ascii 256)})) The version history of the file

#### \`has-edit-permission\`

Checks if a user has edit permission for a file.

Parameters:
- \`file-id\`: (uint) ID of the file
- \`user\`: (principal) Principal of the user to check

Returns: (bool) True if the user has edit permission

#### \`search-files-by-tag\`

Searches for files with a specific tag.

Parameters:
- \`search-tag\`: (string-ascii 32) Tag to search for

Returns: (list uint) List of file IDs that match the tag

#### \`get-user-storage-statistics\`

Retrieves storage statistics for a user.

Parameters:
- \`user\`: (principal) Principal of the user

Returns: (ok {total-files-count: uint, total-storage-used: uint, last-upload-timestamp: uint}) Storage statistics for the user

## Important Considerations

1. **File Size Limit**: The maximum file size is set to 1GB (1,073,741,824 bytes).
2. **Files Per User**: Each user is limited to 100 files.
3. **Access Control**: File owners can grant and revoke access to other users.
4. **Version History**: The contract maintains a version history for each file.
5. **Privacy**: Files can be marked as private or public.
6. **Encryption**: The contract supports flagging files as encrypted, but actual encryption must be handled off-chain.
7. **Storage**: The contract only stores metadata and file hashes. Actual file content should be stored off-chain (e.g., IPFS).

## Security Notes

- Ensure that sensitive data is encrypted before uploading.
- Regularly review and revoke unnecessary access permissions.
- Be cautious when granting edit permissions to other users.

## Limitations

- The contract does not handle the actual file storage or transfer. It only manages metadata and access control.
- There's no built-in mechanism for file content verification. Users should implement their own verification methods.