
;; Define the contract owner
(define-data-var contract-owner principal tx-sender)


;; Define data variables
(define-data-var proposal-counter uint u0)

(define-map proposals
  { proposal-id: uint }
  {
    description: (string-ascii 500),
    is-active: bool,
    title: (string-ascii 50),
    votes-against: uint,
    votes-for: uint,
    total-users: uint  ;; Added field
  }
)

(define-map proposal-categories
  { proposal-id: uint }
  { category: (string-ascii 20) }
)


(define-map votes
  { voter: principal, proposal-id: uint }
  { vote: bool })

(define-map proposal-creation-heights
  { proposal-id: uint }
  { creation-height: uint }
)
(define-map proposal-comments
  { proposal-id: uint, comment-id: uint }
  { commenter: principal, comment: (string-ascii 200) }
)


(define-public (create-proposal (title (string-ascii 50)) (description (string-ascii 500)))
  (let ((proposal-id (var-get next-proposal-id)))
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        is-active: true,
        votes-for: u0,
        votes-against: u0,
        total-users: u0  ;; Initialize the new field
      })
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)))


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


;; created dd-category-to-proposal
(define-public (add-category-to-proposal (proposal-id uint) (category (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (asserts! (is-some (map-get? proposals { proposal-id: proposal-id })) (err u404))
    (ok (map-set proposal-categories { proposal-id: proposal-id } { category: category }))
  )
)

(define-read-only (get-proposal-category (proposal-id uint))
  (map-get? proposal-categories { proposal-id: proposal-id })
)


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



(define-data-var next-proposal-id uint u0)


(define-data-var proposal-quorum-percentage uint u25) ;; 25% quorum

(define-read-only (get-proposal-total-users (proposal-id uint))
  (let ((proposal (unwrap-panic (map-get? proposals { proposal-id: proposal-id }))))
    (ok (get total-users proposal))))

(define-public (increment-total-users (proposal-id uint))
  (let (
    (proposal (unwrap-panic (map-get? proposals { proposal-id: proposal-id })))
    (new-total (+ (get total-users proposal) u1))
  )
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { total-users: new-total }))
    (ok new-total)))



(define-data-var proposal-passing-threshold-percentage uint u60) ;; 60% threshold

(define-private (has-proposal-passed (proposal-id uint))
  (let ((proposal (unwrap-panic (map-get? proposals { proposal-id: proposal-id }))))
    (> (/ (* (get votes-for proposal) u100) (+ (get votes-for proposal) (get votes-against proposal)))
       (var-get proposal-passing-threshold-percentage))))


