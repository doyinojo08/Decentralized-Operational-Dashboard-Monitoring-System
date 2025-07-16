;; Dashboard Coordinator Verification Contract
;; Manages and verifies operational dashboard coordinators

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-COORDINATOR-EXISTS (err u101))
(define-constant ERR-COORDINATOR-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u104))

;; Data Variables
(define-data-var next-coordinator-id uint u1)
(define-data-var total-coordinators uint u0)

;; Data Maps
(define-map coordinators
  { coordinator-id: uint }
  {
    address: principal,
    status: (string-ascii 20),
    reputation: uint,
    permissions: uint,
    created-at: uint,
    last-active: uint
  }
)

(define-map coordinator-by-address
  { address: principal }
  { coordinator-id: uint }
)

(define-map coordinator-metrics
  { coordinator-id: uint }
  {
    tasks-completed: uint,
    success-rate: uint,
    response-time: uint,
    uptime-percentage: uint
  }
)

;; Public Functions

;; Register a new coordinator
(define-public (register-coordinator)
  (let
    (
      (coordinator-id (var-get next-coordinator-id))
      (caller tx-sender)
    )
    (asserts! (is-none (map-get? coordinator-by-address { address: caller })) ERR-COORDINATOR-EXISTS)

    (map-set coordinators
      { coordinator-id: coordinator-id }
      {
        address: caller,
        status: "active",
        reputation: u100,
        permissions: u1,
        created-at: block-height,
        last-active: block-height
      }
    )

    (map-set coordinator-by-address
      { address: caller }
      { coordinator-id: coordinator-id }
    )

    (map-set coordinator-metrics
      { coordinator-id: coordinator-id }
      {
        tasks-completed: u0,
        success-rate: u100,
        response-time: u0,
        uptime-percentage: u100
      }
    )

    (var-set next-coordinator-id (+ coordinator-id u1))
    (var-set total-coordinators (+ (var-get total-coordinators) u1))

    (ok coordinator-id)
  )
)

;; Update coordinator status
(define-public (update-coordinator-status (coordinator-id uint) (new-status (string-ascii 20)))
  (let
    (
      (coordinator (unwrap! (map-get? coordinators { coordinator-id: coordinator-id }) ERR-COORDINATOR-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get address coordinator))) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq new-status "active") (is-eq new-status "inactive") (is-eq new-status "suspended")) ERR-INVALID-STATUS)

    (map-set coordinators
      { coordinator-id: coordinator-id }
      (merge coordinator { status: new-status, last-active: block-height })
    )

    (ok true)
  )
)

;; Update coordinator reputation
(define-public (update-reputation (coordinator-id uint) (reputation-change int))
  (let
    (
      (coordinator (unwrap! (map-get? coordinators { coordinator-id: coordinator-id }) ERR-COORDINATOR-NOT-FOUND))
      (current-reputation (get reputation coordinator))
      (new-reputation (if (> reputation-change 0)
                        (+ current-reputation (to-uint reputation-change))
                        (if (> current-reputation (to-uint (- 0 reputation-change)))
                          (- current-reputation (to-uint (- 0 reputation-change)))
                          u0)))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set coordinators
      { coordinator-id: coordinator-id }
      (merge coordinator { reputation: new-reputation, last-active: block-height })
    )

    (ok new-reputation)
  )
)

;; Update coordinator permissions
(define-public (update-permissions (coordinator-id uint) (new-permissions uint))
  (let
    (
      (coordinator (unwrap! (map-get? coordinators { coordinator-id: coordinator-id }) ERR-COORDINATOR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-permissions u5) ERR-INVALID-STATUS)

    (map-set coordinators
      { coordinator-id: coordinator-id }
      (merge coordinator { permissions: new-permissions, last-active: block-height })
    )

    (ok true)
  )
)

;; Update coordinator metrics
(define-public (update-metrics (coordinator-id uint) (tasks-completed uint) (success-rate uint) (response-time uint) (uptime-percentage uint))
  (let
    (
      (coordinator (unwrap! (map-get? coordinators { coordinator-id: coordinator-id }) ERR-COORDINATOR-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get address coordinator))) ERR-NOT-AUTHORIZED)
    (asserts! (<= success-rate u100) ERR-INVALID-STATUS)
    (asserts! (<= uptime-percentage u100) ERR-INVALID-STATUS)

    (map-set coordinator-metrics
      { coordinator-id: coordinator-id }
      {
        tasks-completed: tasks-completed,
        success-rate: success-rate,
        response-time: response-time,
        uptime-percentage: uptime-percentage
      }
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get coordinator details
(define-read-only (get-coordinator (coordinator-id uint))
  (map-get? coordinators { coordinator-id: coordinator-id })
)

;; Get coordinator by address
(define-read-only (get-coordinator-by-address (address principal))
  (match (map-get? coordinator-by-address { address: address })
    coordinator-data (map-get? coordinators { coordinator-id: (get coordinator-id coordinator-data) })
    none
  )
)

;; Get coordinator metrics
(define-read-only (get-coordinator-metrics (coordinator-id uint))
  (map-get? coordinator-metrics { coordinator-id: coordinator-id })
)

;; Check if coordinator is authorized
(define-read-only (is-authorized-coordinator (coordinator-id uint) (required-permission uint))
  (match (map-get? coordinators { coordinator-id: coordinator-id })
    coordinator (and
                  (is-eq (get status coordinator) "active")
                  (>= (get permissions coordinator) required-permission)
                  (>= (get reputation coordinator) u50))
    false
  )
)

;; Get total coordinators
(define-read-only (get-total-coordinators)
  (var-get total-coordinators)
)

;; Verify coordinator exists and is active
(define-read-only (verify-coordinator (coordinator-id uint))
  (match (map-get? coordinators { coordinator-id: coordinator-id })
    coordinator (is-eq (get status coordinator) "active")
    false
  )
)
