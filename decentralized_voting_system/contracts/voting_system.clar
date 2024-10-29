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
