
;; Define the contract owner
(define-data-var contract-owner principal tx-sender)


;; Define data variables
(define-data-var proposal-counter uint u0)
(define-map proposals
  { proposal-id: uint }
  { title: (string-ascii 50),
    description: (string-ascii 500),
    votes-for: uint,
    votes-against: uint,
    is-active: bool })

(define-map votes
  { voter: principal, proposal-id: uint }
  { vote: bool })


;; Create a new proposal
(define-public (create-proposal (title (string-ascii 50)) (description (string-ascii 500)))
  (let ((new-id (+ (var-get proposal-counter) u1)))
    (map-set proposals
      { proposal-id: new-id }
      { title: title,
        description: description,
        votes-for: u0,
        votes-against: u0,
        is-active: true })
    (var-set proposal-counter new-id)
    (ok new-id)))

;; Cast a vote
(define-public (cast-vote (proposal-id uint) (vote bool))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err u404))))
    (asserts! (get is-active proposal) (err u403))
    (asserts! (is-none (map-get? votes { voter: tx-sender, proposal-id: proposal-id })) (err u401))
    (map-set votes { voter: tx-sender, proposal-id: proposal-id } { vote: vote })
    (if vote
      (map-set proposals { proposal-id: proposal-id }
        (merge proposal { votes-for: (+ (get votes-for proposal) u1) }))
      (map-set proposals { proposal-id: proposal-id }
        (merge proposal { votes-against: (+ (get votes-against proposal) u1) })))
    (ok true)))

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id }))


;; Close a proposal
(define-public (close-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err u404))))
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (ok (map-set proposals { proposal-id: proposal-id }
         (merge proposal { is-active: false })))))

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner))


;; Change contract owner (only current owner can do this)
(define-public (change-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (ok (var-set contract-owner new-owner))))


;; Get Voter's Vote
(define-read-only (get-voter-vote (proposal-id uint) (voter principal))
  (map-get? votes { voter: voter, proposal-id: proposal-id }))

;; Helper function to check if proposal is active
(define-private (is-proposal-active (proposal-id uint))
(let ((proposal (unwrap-panic (map-get? proposals {proposal-id: proposal-id}))))
(get is-active proposal)))


(define-data-var proposal-voting-period-days uint u3)

(define-private (is-proposal-voting-period-over (proposal-id uint))
  (let ((proposal (unwrap-panic (map-get? proposals { proposal-id: proposal-id }))))
    (> (- (as-max-len? (var-get block-height) u32) (get block-height proposal)) (* (var-get proposal-voting-period-days) u144)))) ;; Assuming 144 blocks per day


(define-public (cast-vote (proposal-id uint) (vote bool))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err u404))))
    (asserts! (get is-active proposal) (err u403)) ;; Use the is-active getter from the proposal map
    (asserts! (not (is-proposal-voting-period-over proposal-id)) (err u403))
    ;; Rest of the cast-vote function remains the same
  )
)

(define-public (close-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err u404))))
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (asserts! (is-proposal-voting-period-over proposal-id) (err u403))
    (ok (map-set proposals { proposal-id: proposal-id }
         (merge proposal { is-active: false })))))

(define-data-var proposal-quorum-percentage uint u25) ;; 25% quorum

(define-private (has-proposal-quorum (proposal-id uint))
  (let ((proposal (unwrap-panic (map-get? proposals { proposal-id: proposal-id }))))
    (>= (+ (get votes-for proposal) (get votes-against proposal))
        (/ (* (var-get proposal-quorum-percentage) (get totalUsers proposal)) u100)))) ;; Assuming totalUsers is stored in the proposal


(define-data-var proposal-passing-threshold-percentage uint u60) ;; 60% threshold

(define-private (has-proposal-passed (proposal-id uint))
  (let ((proposal (unwrap-panic (map-get? proposals { proposal-id: proposal-id }))))
    (> (/ (* (get votes-for proposal) u100) (+ (get votes-for proposal) (get votes-against proposal)))
       (var-get proposal-passing-threshold-percentage))))

(define-public (close-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err u404))))
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (asserts! (is-proposal-voting-period-over proposal-id) (err u403))
    (asserts! (has-proposal-passed proposal-id) (err u403)) ;; Only allow closing if proposal passed
    (ok (map-set proposals { proposal-id: proposal-id }
         (merge proposal { is-active: false })))))
