;; decentralized_voting_system


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
