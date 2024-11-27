;; File sharing smart contract

(define-constant contract-owner tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-FILE-EXISTS (err u104))
(define-constant ERR-STORAGE-LIMIT (err u105))

;; Storage Constants
(define-constant maximum-file-size u1073741824) ;; 1GB in bytes
(define-constant maximum-files-per-user u100)

;; Data Maps
(define-map file-records 
    { file-id: uint }
    {
        owner: principal,
        file-name: (string-ascii 64),
        file-hash: (string-ascii 64),
        file-size: uint,
        upload-timestamp: uint,
        last-modified-timestamp: uint,
        file-type: (string-ascii 32),
        file-description: (string-ascii 256),
        is-private: bool,
        is-encrypted: bool,
        version-number: uint
    }
)

(define-map file-access-permissions 
    { file-id: uint, user: principal } 
    { 
        can-access: bool,
        can-edit: bool,
        access-granted-timestamp: uint,
        access-expiration-timestamp: (optional uint)
    }
)

(define-map user-storage-stats
    { user: principal }
    {
        total-files-count: uint,
        total-storage-used: uint,
        last-upload-timestamp: uint
    }
)

(define-map file-version-history
    { file-id: uint, version-number: uint }
    {
        file-hash: (string-ascii 64),
        file-size: uint,
        modified-by-user: principal,
        modification-timestamp: uint,
        change-description: (string-ascii 256)
    }
)

(define-map file-tag-associations
    { file-id: uint }
    { tag-list: (list 10 (string-ascii 32)) }
)

(define-data-var file-id-counter uint u0)

;; Private Functions
(define-private (is-file-owner (file-id uint))
    (let ((file-record (unwrap! (map-get? file-records { file-id: file-id }) ERR-NOT-FOUND)))
        (is-eq (get owner file-record) tx-sender)
    )
)

(define-private (has-file-access (file-id uint) (user principal))
    (let (
        (file-record (unwrap! (map-get? file-records { file-id: file-id }) ERR-NOT-FOUND))
        (access-entry (map-get? file-access-permissions { file-id: file-id, user: user }))
    )
        (or 
            (is-eq (get owner file-record) user)
            (not (get is-private file-record))
            (and 
                (is-some access-entry)
                (get can-access (unwrap! access-entry false))
                (let ((expiration-time (get access-expiration-timestamp (unwrap! access-entry false))))
                    (or
                        (is-none expiration-time)
                        (> (unwrap! expiration-time u0) block-height)
                    )
                )
            )
        )
    )
)

(define-private (update-user-storage-stats (user principal) (size-change int))
    (let (
        (current-stats (default-to 
            { total-files-count: u0, total-storage-used: u0, last-upload-timestamp: u0 }
            (map-get? user-storage-stats { user: user })
        ))
    )
        (map-set user-storage-stats
            { user: user }
            {
                total-files-count: (+ (get total-files-count current-stats) u1),
                total-storage-used: (+ (get total-storage-used current-stats) (if (> size-change 0) (to-uint size-change) u0)),
                last-upload-timestamp: block-height
            }
        )
    )
)

;; Public Functions
(define-public (upload-new-file 
    (file-name (string-ascii 64)) 
    (file-hash (string-ascii 64)) 
    (file-size uint)
    (file-type (string-ascii 32))
    (file-description (string-ascii 256))
    (is-private bool)
    (is-encrypted bool)
    (file-tags (list 10 (string-ascii 32)))
)
    (let (
        (new-file-id (+ (var-get file-id-counter) u1))
        (user-storage-info (default-to 
            { total-files-count: u0, total-storage-used: u0, last-upload-timestamp: u0 }
            (map-get? user-storage-stats { user: tx-sender })
        ))
    )
        (asserts! (<= file-size maximum-file-size) ERR-INVALID-INPUT)
        (asserts! (< (get total-files-count user-storage-info) maximum-files-per-user) ERR-STORAGE-LIMIT)
        
        (var-set file-id-counter new-file-id)
        (map-set file-records
            { file-id: new-file-id }
            {
                owner: tx-sender,
                file-name: file-name,
                file-hash: file-hash,
                file-size: file-size,
                upload-timestamp: block-height,
                last-modified-timestamp: block-height,
                file-type: file-type,
                file-description: file-description,
                is-private: is-private,
                is-encrypted: is-encrypted,
                version-number: u1
            }
        )
        
        (map-set file-tag-associations { file-id: new-file-id } { tag-list: file-tags })
        (map-set file-version-history
            { file-id: new-file-id, version-number: u1 }
            {
                file-hash: file-hash,
                file-size: file-size,
                modified-by-user: tx-sender,
                modification-timestamp: block-height,
                change-description: "Initial upload"
            }
        )
        
        (update-user-storage-stats tx-sender (to-int file-size))
        (ok new-file-id)
    )
)

(define-public (update-existing-file 
    (file-id uint)
    (new-file-hash (string-ascii 64))
    (new-file-size uint)
    (change-description (string-ascii 256))
)
    (let (
        (file-record (unwrap! (map-get? file-records { file-id: file-id }) ERR-NOT-FOUND))
        (new-version-number (+ (get version-number file-record) u1))
    )
        (asserts! (or (is-file-owner file-id) (has-edit-permission file-id tx-sender)) ERR-UNAUTHORIZED)
        (asserts! (<= new-file-size maximum-file-size) ERR-INVALID-INPUT)
        
        (map-set file-records
            { file-id: file-id }
            (merge file-record {
                file-hash: new-file-hash,
                file-size: new-file-size,
                last-modified-timestamp: block-height,
                version-number: new-version-number
            })
        )
        
        (map-set file-version-history
            { file-id: file-id, version-number: new-version-number }
            {
                file-hash: new-file-hash,
                file-size: new-file-size,
                modified-by-user: tx-sender,
                modification-timestamp: block-height,
                change-description: change-description
            }
        )
        
        (update-user-storage-stats (get owner file-record) (- (to-int new-file-size) (to-int (get file-size file-record))))
        (ok new-version-number)
    )
)

(define-public (grant-file-access-with-expiry 
    (file-id uint) 
    (user principal)
    (allow-edit bool)
    (expiration-time (optional uint))
)
    (begin
        (asserts! (is-file-owner file-id) ERR-UNAUTHORIZED)
        (map-set file-access-permissions
            { file-id: file-id, user: user }
            {
                can-access: true,
                can-edit: allow-edit,
                access-granted-timestamp: block-height,
                access-expiration-timestamp: expiration-time
            }
        )
        (ok true)
    )
)

(define-public (update-file-metadata
    (file-id uint)
    (new-file-name (optional (string-ascii 64)))
    (new-file-description (optional (string-ascii 256)))
    (new-file-tags (optional (list 10 (string-ascii 32))))
)
    (let ((file-record (unwrap! (map-get? file-records { file-id: file-id }) ERR-NOT-FOUND)))
        (asserts! (is-file-owner file-id) ERR-UNAUTHORIZED)
        
        (if (is-some new-file-name)
            (map-set file-records
                { file-id: file-id }
                (merge file-record { file-name: (unwrap! new-file-name "") })
            )
            true
        )
        
        (if (is-some new-file-description)
            (map-set file-records
                { file-id: file-id }
                (merge file-record { file-description: (unwrap! new-file-description "") })
            )
            true
        )
        
        (if (is-some new-file-tags)
            (map-set file-tag-associations
                { file-id: file-id }
                { tag-list: (unwrap! new-file-tags (list)) }
            )
            true
        )
        
        (ok true)
    )
)

(define-read-only (get-file-version-history (file-id uint))
    (begin
        (asserts! (has-file-access file-id tx-sender) ERR-UNAUTHORIZED)
        (ok (map-get? file-version-history { file-id: file-id, version-number: u1 }))
    )
)

(define-read-only (has-edit-permission (file-id uint) (user principal))
    (let ((access-entry (map-get? file-access-permissions { file-id: file-id, user: user })))
        (and
            (is-some access-entry)
            (get can-edit (unwrap! access-entry false))
            (let ((expiration-time (get access-expiration-timestamp (unwrap! access-entry false))))
                (or
                    (is-none expiration-time)
                    (> (unwrap! expiration-time u0) block-height)
                )
            )
        )
    )
)

(define-read-only (search-files-by-tag (search-tag (string-ascii 32)))
    (filter
        (lambda (file-id)
            (let ((tags-entry (map-get? file-tag-associations { file-id: file-id })))
                (and
                    (is-some tags-entry)
                    (is-some (index-of (get tag-list (unwrap! tags-entry { tag-list: (list) })) search-tag))
                    (has-file-access file-id tx-sender)
                )
            )
        )
        (map-keys file-records)
    )
)

(define-read-only (get-user-storage-statistics (user principal))
    (ok (default-to
        { total-files-count: u0, total-storage-used: u0, last-upload-timestamp: u0 }
        (map-get? user-storage-stats { user: user })
    ))
)