;; Climate Intervention Risk Assessment Contract
;; Evaluates potential unintended consequences of geoengineering

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-ASSESSMENT (err u401))
(define-constant ERR-ASSESSMENT-NOT-FOUND (err u402))
(define-constant ERR-INVALID-RISK-SCORE (err u403))
(define-constant ERR-INSUFFICIENT-DATA (err u404))

;; Data Variables
(define-data-var assessment-counter uint u0)
(define-data-var scenario-counter uint u0)
(define-data-var high-risk-threshold uint u70) ;; Risk scores above 70 are high risk

;; Data Maps
(define-map risk-assessments
  { assessment-id: uint }
  {
    intervention-type: (string-ascii 50),
    scale: (string-ascii 20), ;; local, regional, global
    assessor: principal,
    environmental-risk: uint,
    social-risk: uint,
    economic-risk: uint,
    technical-risk: uint,
    overall-risk-score: uint,
    confidence-level: uint,
    assessment-date: uint,
    status: (string-ascii 20),
    recommendations: (string-ascii 500)
  }
)

(define-map risk-assessors
  { address: principal }
  {
    name: (string-ascii 100),
    qualifications: (string-ascii 200),
    specialization: (list 3 (string-ascii 50)),
    assessment-count: uint,
    average-confidence: uint,
    active: bool
  }
)

(define-map risk-scenarios
  { scenario-id: uint }
  {
    assessment-id: uint,
    scenario-name: (string-ascii 100),
    probability: uint, ;; percentage
    impact-severity: uint, ;; 1-10 scale
    affected-regions: (list 5 (string-ascii 50)),
    time-horizon: uint, ;; years
    mitigation-strategies: (string-ascii 300),
    monitoring-requirements: (string-ascii 200)
  }
)

(define-map impact-categories
  { category-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    weight: uint, ;; importance weight in overall assessment
    measurement-criteria: (string-ascii 300)
  }
)

(define-map mitigation-plans
  { plan-id: uint }
  {
    assessment-id: uint,
    risk-category: (string-ascii 50),
    mitigation-actions: (string-ascii 400),
    implementation-timeline: uint,
    cost-estimate: uint,
    effectiveness-rating: uint,
    responsible-party: (string-ascii 100),
    status: (string-ascii 20)
  }
)

;; Private Functions
(define-private (is-authorized-assessor (caller principal))
  (match (map-get? risk-assessors { address: caller })
    assessor (get active assessor)
    false
  )
)

(define-private (calculate-overall-risk (env uint) (social uint) (econ uint) (tech uint))
  (let (
    (weighted-env (* env u25))
    (weighted-social (* social u25))
    (weighted-econ (* econ u25))
    (weighted-tech (* tech u25))
  )
    (/ (+ weighted-env weighted-social weighted-econ weighted-tech) u100)
  )
)

(define-private (is-high-risk (risk-score uint))
  (>= risk-score (var-get high-risk-threshold))
)

;; Public Functions
(define-public (register-assessor
  (address principal)
  (name (string-ascii 100))
  (qualifications (string-ascii 200))
  (specialization (list 3 (string-ascii 50)))
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set risk-assessors
      { address: address }
      {
        name: name,
        qualifications: qualifications,
        specialization: specialization,
        assessment-count: u0,
        average-confidence: u0,
        active: true
      }
    ))
  )
)

(define-public (submit-risk-assessment
  (intervention-type (string-ascii 50))
  (scale (string-ascii 20))
  (environmental-risk uint)
  (social-risk uint)
  (economic-risk uint)
  (technical-risk uint)
  (confidence-level uint)
  (recommendations (string-ascii 500))
)
  (let ((assessment-id (+ (var-get assessment-counter) u1)))
    (asserts! (is-authorized-assessor tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (and (<= environmental-risk u100) (<= social-risk u100) (<= economic-risk u100) (<= technical-risk u100)) ERR-INVALID-RISK-SCORE)
    (asserts! (and (>= confidence-level u0) (<= confidence-level u100)) ERR-INVALID-ASSESSMENT)

    (let ((overall-risk (calculate-overall-risk environmental-risk social-risk economic-risk technical-risk)))
      (map-set risk-assessments
        { assessment-id: assessment-id }
        {
          intervention-type: intervention-type,
          scale: scale,
          assessor: tx-sender,
          environmental-risk: environmental-risk,
          social-risk: social-risk,
          economic-risk: economic-risk,
          technical-risk: technical-risk,
          overall-risk-score: overall-risk,
          confidence-level: confidence-level,
          assessment-date: block-height,
          status: (if (is-high-risk overall-risk) "high-risk" "acceptable"),
          recommendations: recommendations
        }
      )

      ;; Update assessor statistics
      (match (map-get? risk-assessors { address: tx-sender })
        assessor
        (let ((new-count (+ (get assessment-count assessor) u1)))
          (map-set risk-assessors
            { address: tx-sender }
            (merge assessor {
              assessment-count: new-count,
              average-confidence: (/ (+ (* (get average-confidence assessor) (get assessment-count assessor)) confidence-level) new-count)
            })
          )
        )
        false
      )

      (var-set assessment-counter assessment-id)
      (ok assessment-id)
    )
  )
)

(define-public (create-risk-scenario
  (assessment-id uint)
  (scenario-name (string-ascii 100))
  (probability uint)
  (impact-severity uint)
  (affected-regions (list 5 (string-ascii 50)))
  (time-horizon uint)
  (mitigation-strategies (string-ascii 300))
  (monitoring-requirements (string-ascii 200))
)
  (let (
    (assessment (unwrap! (map-get? risk-assessments { assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND))
    (scenario-id (+ (var-get scenario-counter) u1))
  )
    (asserts! (is-eq tx-sender (get assessor assessment)) ERR-NOT-AUTHORIZED)
    (asserts! (and (<= probability u100) (>= impact-severity u1) (<= impact-severity u10)) ERR-INVALID-ASSESSMENT)

    (map-set risk-scenarios
      { scenario-id: scenario-id }
      {
        assessment-id: assessment-id,
        scenario-name: scenario-name,
        probability: probability,
        impact-severity: impact-severity,
        affected-regions: affected-regions,
        time-horizon: time-horizon,
        mitigation-strategies: mitigation-strategies,
        monitoring-requirements: monitoring-requirements
      }
    )

    (var-set scenario-counter scenario-id)
    (ok scenario-id)
  )
)

(define-public (create-mitigation-plan
  (assessment-id uint)
  (risk-category (string-ascii 50))
  (mitigation-actions (string-ascii 400))
  (implementation-timeline uint)
  (cost-estimate uint)
  (effectiveness-rating uint)
  (responsible-party (string-ascii 100))
)
  (let (
    (assessment (unwrap! (map-get? risk-assessments { assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND))
    (plan-id (+ assessment-id u1000)) ;; Simple plan ID generation
  )
    (asserts! (is-authorized-assessor tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (and (<= effectiveness-rating u100) (> implementation-timeline u0)) ERR-INVALID-ASSESSMENT)

    (map-set mitigation-plans
      { plan-id: plan-id }
      {
        assessment-id: assessment-id,
        risk-category: risk-category,
        mitigation-actions: mitigation-actions,
        implementation-timeline: implementation-timeline,
        cost-estimate: cost-estimate,
        effectiveness-rating: effectiveness-rating,
        responsible-party: responsible-party,
        status: "proposed"
      }
    )

    (ok plan-id)
  )
)

(define-public (approve-mitigation-plan (plan-id uint))
  (let ((plan (unwrap! (map-get? mitigation-plans { plan-id: plan-id }) ERR-ASSESSMENT-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status plan) "proposed") ERR-INVALID-ASSESSMENT)

    (map-set mitigation-plans
      { plan-id: plan-id }
      (merge plan { status: "approved" })
    )

    (ok true)
  )
)

(define-public (update-assessment-status (assessment-id uint) (new-status (string-ascii 20)))
  (let ((assessment (unwrap! (map-get? risk-assessments { assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set risk-assessments
      { assessment-id: assessment-id }
      (merge assessment { status: new-status })
    )

    (ok true)
  )
)

(define-public (define-impact-category
  (name (string-ascii 50))
  (description (string-ascii 200))
  (weight uint)
  (measurement-criteria (string-ascii 300))
)
  (let ((category-id (+ (var-get assessment-counter) u500))) ;; Simple category ID generation
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= weight u100) ERR-INVALID-ASSESSMENT)

    (map-set impact-categories
      { category-id: category-id }
      {
        name: name,
        description: description,
        weight: weight,
        measurement-criteria: measurement-criteria
      }
    )

    (ok category-id)
  )
)

;; Read-only Functions
(define-read-only (get-risk-assessment (assessment-id uint))
  (map-get? risk-assessments { assessment-id: assessment-id })
)

(define-read-only (get-risk-assessor (address principal))
  (map-get? risk-assessors { address: address })
)

(define-read-only (get-risk-scenario (scenario-id uint))
  (map-get? risk-scenarios { scenario-id: scenario-id })
)

(define-read-only (get-mitigation-plan (plan-id uint))
  (map-get? mitigation-plans { plan-id: plan-id })
)

(define-read-only (get-impact-category (category-id uint))
  (map-get? impact-categories { category-id: category-id })
)

(define-read-only (get-assessment-count)
  (var-get assessment-counter)
)

(define-read-only (get-scenario-count)
  (var-get scenario-counter)
)

(define-read-only (is-assessment-high-risk (assessment-id uint))
  (match (map-get? risk-assessments { assessment-id: assessment-id })
    assessment (is-high-risk (get overall-risk-score assessment))
    false
  )
)
