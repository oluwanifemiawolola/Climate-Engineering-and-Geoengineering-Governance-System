;; International Climate Governance Contract
;; Coordinates global climate intervention policies and agreements

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-TREATY (err u501))
(define-constant ERR-TREATY-NOT-FOUND (err u502))
(define-constant ERR-ALREADY-SIGNED (err u503))
(define-constant ERR-NOT-SIGNATORY (err u504))
(define-constant ERR-DISPUTE-NOT-FOUND (err u505))

;; Data Variables
(define-data-var treaty-counter uint u0)
(define-data-var dispute-counter uint u0)
(define-data-var resource-pool uint u0)

;; Data Maps
(define-map treaties
  { treaty-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    treaty-type: (string-ascii 50),
    scope: (string-ascii 100),
    signatories: (list 20 principal),
    required-signatures: uint,
    current-signatures: uint,
    creation-date: uint,
    effective-date: uint,
    status: (string-ascii 20),
    compliance-requirements: (string-ascii 400)
  }
)

(define-map nations
  { address: principal }
  {
    name: (string-ascii 50),
    region: (string-ascii 50),
    population: uint,
    gdp: uint,
    climate-vulnerability: uint, ;; 1-10 scale
    voting-weight: uint,
    active: bool,
    treaty-count: uint
  }
)

(define-map treaty-signatures
  { treaty-id: uint, signatory: principal }
  {
    signature-date: uint,
    ratification-status: (string-ascii 20),
    conditions: (string-ascii 200),
    compliance-score: uint
  }
)

(define-map disputes
  { dispute-id: uint }
  {
    treaty-id: uint,
    complainant: principal,
    respondent: principal,
    dispute-type: (string-ascii 50),
    description: (string-ascii 400),
    filing-date: uint,
    status: (string-ascii 20),
    resolution: (string-ascii 300),
    arbitrator: principal
  }
)

(define-map resource-allocations
  { allocation-id: uint }
  {
    treaty-id: uint,
    recipient: principal,
    amount: uint,
    purpose: (string-ascii 200),
    allocation-date: uint,
    disbursement-schedule: (string-ascii 100),
    status: (string-ascii 20),
    conditions: (string-ascii 200)
  }
)

(define-map compliance-reports
  { report-id: uint }
  {
    treaty-id: uint,
    reporting-nation: principal,
    reporting-period: uint,
    compliance-score: uint,
    achievements: (string-ascii 300),
    challenges: (string-ascii 300),
    next-steps: (string-ascii 200),
    verified: bool
  }
)

;; Private Functions
(define-private (is-authorized-nation (caller principal))
  (match (map-get? nations { address: caller })
    nation (get active nation)
    false
  )
)

(define-private (is-treaty-signatory (treaty-id uint) (nation principal))
  (is-some (map-get? treaty-signatures { treaty-id: treaty-id, signatory: nation }))
)

(define-private (calculate-voting-weight (population uint) (gdp uint) (vulnerability uint))
  (let (
    (pop-weight (/ population u1000000)) ;; Population in millions
    (gdp-weight (/ gdp u1000000000)) ;; GDP in billions
    (vuln-weight (* vulnerability u2)) ;; Vulnerability multiplier
  )
    (+ pop-weight gdp-weight vuln-weight)
  )
)

;; Public Functions
(define-public (register-nation
  (address principal)
  (name (string-ascii 50))
  (region (string-ascii 50))
  (population uint)
  (gdp uint)
  (climate-vulnerability uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= climate-vulnerability u1) (<= climate-vulnerability u10)) ERR-INVALID-TREATY)

    (let ((voting-weight (calculate-voting-weight population gdp climate-vulnerability)))
      (map-set nations
        { address: address }
        {
          name: name,
          region: region,
          population: population,
          gdp: gdp,
          climate-vulnerability: climate-vulnerability,
          voting-weight: voting-weight,
          active: true,
          treaty-count: u0
        }
      )
    )
    (ok true)
  )
)

(define-public (propose-treaty
  (title (string-ascii 100))
  (description (string-ascii 500))
  (treaty-type (string-ascii 50))
  (scope (string-ascii 100))
  (required-signatures uint)
  (compliance-requirements (string-ascii 400))
)
  (let ((treaty-id (+ (var-get treaty-counter) u1)))
    (asserts! (is-authorized-nation tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> required-signatures u0) ERR-INVALID-TREATY)

    (map-set treaties
      { treaty-id: treaty-id }
      {
        title: title,
        description: description,
        treaty-type: treaty-type,
        scope: scope,
        signatories: (list tx-sender),
        required-signatures: required-signatures,
        current-signatures: u1,
        creation-date: block-height,
        effective-date: u0,
        status: "proposed",
        compliance-requirements: compliance-requirements
      }
    )

    ;; Record proposer as first signatory
    (map-set treaty-signatures
      { treaty-id: treaty-id, signatory: tx-sender }
      {
        signature-date: block-height,
        ratification-status: "signed",
        conditions: "",
        compliance-score: u100
      }
    )

    (var-set treaty-counter treaty-id)
    (ok treaty-id)
  )
)

(define-public (sign-treaty (treaty-id uint) (conditions (string-ascii 200)))
  (let ((treaty (unwrap! (map-get? treaties { treaty-id: treaty-id }) ERR-TREATY-NOT-FOUND)))
    (asserts! (is-authorized-nation tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-treaty-signatory treaty-id tx-sender)) ERR-ALREADY-SIGNED)
    (asserts! (is-eq (get status treaty) "proposed") ERR-INVALID-TREATY)

    ;; Record signature
    (map-set treaty-signatures
      { treaty-id: treaty-id, signatory: tx-sender }
      {
        signature-date: block-height,
        ratification-status: "signed",
        conditions: conditions,
        compliance-score: u100
      }
    )

    ;; Update treaty with new signatory
    (let ((new-signature-count (+ (get current-signatures treaty) u1)))
      (map-set treaties
        { treaty-id: treaty-id }
        (merge treaty {
          signatories: (unwrap-panic (as-max-len? (append (get signatories treaty) tx-sender) u20)),
          current-signatures: new-signature-count,
          status: (if (>= new-signature-count (get required-signatures treaty)) "active" "proposed"),
          effective-date: (if (>= new-signature-count (get required-signatures treaty)) block-height u0)
        })
      )

      ;; Update nation treaty count
      (match (map-get? nations { address: tx-sender })
        nation
        (map-set nations
          { address: tx-sender }
          (merge nation { treaty-count: (+ (get treaty-count nation) u1) })
        )
        false
      )

      (ok new-signature-count)
    )
  )
)

(define-public (file-dispute
  (treaty-id uint)
  (respondent principal)
  (dispute-type (string-ascii 50))
  (description (string-ascii 400))
)
  (let (
    (treaty (unwrap! (map-get? treaties { treaty-id: treaty-id }) ERR-TREATY-NOT-FOUND))
    (dispute-id (+ (var-get dispute-counter) u1))
  )
    (asserts! (is-treaty-signatory treaty-id tx-sender) ERR-NOT-SIGNATORY)
    (asserts! (is-treaty-signatory treaty-id respondent) ERR-NOT-SIGNATORY)
    (asserts! (is-eq (get status treaty) "active") ERR-INVALID-TREATY)

    (map-set disputes
      { dispute-id: dispute-id }
      {
        treaty-id: treaty-id,
        complainant: tx-sender,
        respondent: respondent,
        dispute-type: dispute-type,
        description: description,
        filing-date: block-height,
        status: "filed",
        resolution: "",
        arbitrator: CONTRACT-OWNER ;; Default arbitrator
      }
    )

    (var-set dispute-counter dispute-id)
    (ok dispute-id)
  )
)

(define-public (resolve-dispute (dispute-id uint) (resolution (string-ascii 300)))
  (let ((dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) ERR-DISPUTE-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get arbitrator dispute)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status dispute) "filed") ERR-INVALID-TREATY)

    (map-set disputes
      { dispute-id: dispute-id }
      (merge dispute {
        status: "resolved",
        resolution: resolution
      })
    )

    (ok true)
  )
)

(define-public (allocate-resources
  (treaty-id uint)
  (recipient principal)
  (amount uint)
  (purpose (string-ascii 200))
  (conditions (string-ascii 200))
)
  (let (
    (treaty (unwrap! (map-get? treaties { treaty-id: treaty-id }) ERR-TREATY-NOT-FOUND))
    (allocation-id (+ treaty-id u2000)) ;; Simple allocation ID generation
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-treaty-signatory treaty-id recipient) ERR-NOT-SIGNATORY)
    (asserts! (<= amount (var-get resource-pool)) ERR-INVALID-TREATY)

    (map-set resource-allocations
      { allocation-id: allocation-id }
      {
        treaty-id: treaty-id,
        recipient: recipient,
        amount: amount,
        purpose: purpose,
        allocation-date: block-height,
        disbursement-schedule: "quarterly",
        status: "approved",
        conditions: conditions
      }
    )

    ;; Update resource pool
    (var-set resource-pool (- (var-get resource-pool) amount))

    (ok allocation-id)
  )
)

(define-public (submit-compliance-report
  (treaty-id uint)
  (reporting-period uint)
  (compliance-score uint)
  (achievements (string-ascii 300))
  (challenges (string-ascii 300))
  (next-steps (string-ascii 200))
)
  (let (
    (treaty (unwrap! (map-get? treaties { treaty-id: treaty-id }) ERR-TREATY-NOT-FOUND))
    (report-id (+ treaty-id reporting-period))
  )
    (asserts! (is-treaty-signatory treaty-id tx-sender) ERR-NOT-SIGNATORY)
    (asserts! (<= compliance-score u100) ERR-INVALID-TREATY)

    (map-set compliance-reports
      { report-id: report-id }
      {
        treaty-id: treaty-id,
        reporting-nation: tx-sender,
        reporting-period: reporting-period,
        compliance-score: compliance-score,
        achievements: achievements,
        challenges: challenges,
        next-steps: next-steps,
        verified: false
      }
    )

    ;; Update signature compliance score
    (match (map-get? treaty-signatures { treaty-id: treaty-id, signatory: tx-sender })
      signature
      (map-set treaty-signatures
        { treaty-id: treaty-id, signatory: tx-sender }
        (merge signature { compliance-score: compliance-score })
      )
      false
    )

    (ok report-id)
  )
)

(define-public (add-to-resource-pool (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set resource-pool (+ (var-get resource-pool) amount))
    (ok (var-get resource-pool))
  )
)

;; Read-only Functions
(define-read-only (get-treaty (treaty-id uint))
  (map-get? treaties { treaty-id: treaty-id })
)

(define-read-only (get-nation (address principal))
  (map-get? nations { address: address })
)

(define-read-only (get-treaty-signature (treaty-id uint) (signatory principal))
  (map-get? treaty-signatures { treaty-id: treaty-id, signatory: signatory })
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes { dispute-id: dispute-id })
)

(define-read-only (get-resource-allocation (allocation-id uint))
  (map-get? resource-allocations { allocation-id: allocation-id })
)

(define-read-only (get-compliance-report (report-id uint))
  (map-get? compliance-reports { report-id: report-id })
)

(define-read-only (get-treaty-count)
  (var-get treaty-counter)
)

(define-read-only (get-dispute-count)
  (var-get dispute-counter)
)

(define-read-only (get-resource-pool-balance)
  (var-get resource-pool)
)

(define-read-only (is-nation-signatory (treaty-id uint) (nation principal))
  (is-treaty-signatory treaty-id nation)
)
