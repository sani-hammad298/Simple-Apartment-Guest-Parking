;; Guest Parking Management Contract
;; Simple visitor parking coordination for apartment complexes

(define-map parking-spots
    { spot-id: uint }
    {
        reserved-by: (optional principal),
        guest-name: (optional (string-ascii 50)),
        reserved-until: (optional uint),
        apartment-unit: (optional (string-ascii 10))
    }
)

(define-map apartment-residents
    { resident: principal }
    { unit-number: (string-ascii 10) }
)

(define-data-var total-spots uint u0)
(define-data-var max-reservation-hours uint u24)

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-SPOT-NOT-FOUND (err u404))
(define-constant ERR-SPOT-OCCUPIED (err u409))
(define-constant ERR-INVALID-DURATION (err u400))
(define-constant ERR-NOT-REGISTERED (err u403))

;; Initialize parking spots
(define-public (initialize-spots (num-spots uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set total-spots num-spots)
        (ok true)
    )
)

;; Register apartment resident
(define-public (register-resident (unit (string-ascii 10)))
    (begin
        (map-set apartment-residents { resident: tx-sender } { unit-number: unit })
        (ok true)
    )
)

;; Reserve parking spot
(define-public (reserve-spot (spot-id uint) (guest-name (string-ascii 50)) (hours uint))
    (let (
        (spot (map-get? parking-spots { spot-id: spot-id }))
        (resident-info (map-get? apartment-residents { resident: tx-sender }))
        (reservation-end (+ stacks-block-height (* hours u6))) ;; ~6 blocks per hour
    )
        (asserts! (is-some resident-info) ERR-NOT-REGISTERED)
        (asserts! (<= spot-id (var-get total-spots)) ERR-SPOT-NOT-FOUND)
        (asserts! (<= hours (var-get max-reservation-hours)) ERR-INVALID-DURATION)

        (match spot
            some-spot (asserts! (is-none (get reserved-by some-spot)) ERR-SPOT-OCCUPIED)
            (asserts! (<= spot-id (var-get total-spots)) ERR-SPOT-NOT-FOUND)
        )

        (map-set parking-spots
            { spot-id: spot-id }
            {
                reserved-by: (some tx-sender),
                guest-name: (some guest-name),
                reserved-until: (some reservation-end),
                apartment-unit: (some (get unit-number (unwrap-panic resident-info)))
            }
        )
        (ok reservation-end)
    )
)

;; Release parking spot
(define-public (release-spot (spot-id uint))
    (let (
        (spot (unwrap! (map-get? parking-spots { spot-id: spot-id }) ERR-SPOT-NOT-FOUND))
    )
        (asserts! (is-eq (some tx-sender) (get reserved-by spot)) ERR-UNAUTHORIZED)
        (map-set parking-spots
            { spot-id: spot-id }
            {
                reserved-by: none,
                guest-name: none,
                reserved-until: none,
                apartment-unit: none
            }
        )
        (ok true)
    )
)

;; Check if reservation has expired
(define-read-only (is-expired (spot-id uint))
    (match (map-get? parking-spots { spot-id: spot-id })
        spot (match (get reserved-until spot)
            expiry (> stacks-block-height expiry)
            false
        )
        false
    )
)

;; Get spot details
(define-read-only (get-spot-info (spot-id uint))
    (map-get? parking-spots { spot-id: spot-id })
)

;; Get all expired reservations
(define-read-only (get-expired-spots)
    (filter is-expired-spot (list-spots))
)

;; Helper functions
(define-data-var contract-owner principal tx-sender)

(define-private (list-spots)
    (map get-spot-number (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20))
)

(define-private (get-spot-number (n uint)) n)

(define-private (is-expired-spot (spot-id uint))
    (is-expired spot-id)
)
