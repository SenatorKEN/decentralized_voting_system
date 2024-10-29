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

