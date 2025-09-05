;; Food Safety Culture Assessment Contract
;; Comprehensive evaluation system for organizational food safety culture

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-ASSESSMENT (err u101))
(define-constant ERR-ASSESSMENT-NOT-FOUND (err u102))
(define-constant ERR-ORGANIZATION-NOT-FOUND (err u103))
(define-constant ERR-INVALID-SCORE (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))

;; Data Variables
(define-data-var assessment-counter uint u0)
(define-data-var organization-counter uint u0)

;; Organization Data Structure
(define-map organizations 
  uint
  {
    name: (string-ascii 100),
    industry-type: (string-ascii 50),
    size: uint,
    contact: principal,
    registered-at: uint,
    status: (string-ascii 20)
  })

;; Assessment Data Structure
(define-map assessments
  uint
  {
    organization-id: uint,
    assessment-type: (string-ascii 30),
    leadership-score: uint,
    communication-score: uint,
    training-score: uint,
    compliance-score: uint,
    culture-score: uint,
    total-score: uint,
    assessed-by: principal,
    assessment-date: uint,
    status: (string-ascii 20),
    recommendations: (string-ascii 500)
  })

;; Assessment History
(define-map assessment-history
  { organization-id: uint, assessment-id: uint }
  {
    previous-total-score: uint,
    improvement-percentage: int,
    areas-improved: (string-ascii 200),
    next-assessment-due: uint
  })

;; Organization Assessors
(define-map authorized-assessors principal bool)

;; Assessment Categories Configuration
(define-map assessment-categories
  (string-ascii 30)
  {
    max-score: uint,
    weight: uint,
    description: (string-ascii 200)
  })

;; Public Functions

;; Register Organization
(define-public (register-organization 
  (name (string-ascii 100))
  (industry-type (string-ascii 50))
  (size uint))
  (let
    ((org-id (+ (var-get organization-counter) u1)))
    (begin
      (map-set organizations org-id {
        name: name,
        industry-type: industry-type,
        size: size,
        contact: tx-sender,
        registered-at: block-height,
        status: "active"
      })
      (var-set organization-counter org-id)
      (ok org-id))))

;; Authorize Assessor
(define-public (authorize-assessor (assessor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-assessors assessor true)
    (ok true)))

;; Create Assessment
(define-public (create-assessment
  (organization-id uint)
  (assessment-type (string-ascii 30))
  (leadership-score uint)
  (communication-score uint)
  (training-score uint)
  (compliance-score uint)
  (culture-score uint)
  (recommendations (string-ascii 500)))
  (let
    ((assessment-id (+ (var-get assessment-counter) u1))
     (total-score (+ (+ (+ (+ leadership-score communication-score) training-score) compliance-score) culture-score))
     (org (map-get? organizations organization-id)))
    (begin
      (asserts! (default-to false (map-get? authorized-assessors tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (is-some org) ERR-ORGANIZATION-NOT-FOUND)
      (asserts! (and (<= leadership-score u100) (<= communication-score u100) 
                     (<= training-score u100) (<= compliance-score u100) 
                     (<= culture-score u100)) ERR-INVALID-SCORE)
      
      (map-set assessments assessment-id {
        organization-id: organization-id,
        assessment-type: assessment-type,
        leadership-score: leadership-score,
        communication-score: communication-score,
        training-score: training-score,
        compliance-score: compliance-score,
        culture-score: culture-score,
        total-score: total-score,
        assessed-by: tx-sender,
        assessment-date: block-height,
        status: "completed",
        recommendations: recommendations
      })
      
      (var-set assessment-counter assessment-id)
      (ok assessment-id))))

;; Update Assessment Status
(define-public (update-assessment-status (assessment-id uint) (new-status (string-ascii 20)))
  (let
    ((assessment (map-get? assessments assessment-id)))
    (begin
      (asserts! (default-to false (map-get? authorized-assessors tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (is-some assessment) ERR-ASSESSMENT-NOT-FOUND)
      
      (map-set assessments assessment-id
        (merge (unwrap! assessment ERR-ASSESSMENT-NOT-FOUND)
               { status: new-status }))
      (ok true))))

;; Calculate Culture Maturity Level
(define-public (calculate-culture-maturity (total-score uint))
  (if (>= total-score u450)
    (ok "Proactive")
    (if (>= total-score u350)
      (ok "Reactive")
      (if (>= total-score u250)
        (ok "Calculative") 
        (if (>= total-score u150)
          (ok "Bureaucratic")
          (ok "Pathological"))))))

;; Record Assessment History
(define-public (record-assessment-history
  (organization-id uint)
  (assessment-id uint)
  (previous-total-score uint)
  (next-assessment-due uint))
  (let
    ((current-assessment (map-get? assessments assessment-id))
     (current-score (get total-score (unwrap! current-assessment ERR-ASSESSMENT-NOT-FOUND)))
     (improvement (- (to-int current-score) (to-int previous-total-score))))
    (begin
      (asserts! (default-to false (map-get? authorized-assessors tx-sender)) ERR-NOT-AUTHORIZED)
      
      (map-set assessment-history
        { organization-id: organization-id, assessment-id: assessment-id }
        {
          previous-total-score: previous-total-score,
          improvement-percentage: improvement,
          areas-improved: "Leadership, Communication",
          next-assessment-due: next-assessment-due
        })
      (ok true))))

;; Initialize Assessment Categories
(define-public (initialize-assessment-categories)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set assessment-categories "leadership" {
      max-score: u100,
      weight: u25,
      description: "Leadership commitment and culture support"
    })
    
    (map-set assessment-categories "communication" {
      max-score: u100,
      weight: u20,
      description: "Communication effectiveness and transparency"
    })
    
    (map-set assessment-categories "training" {
      max-score: u100,
      weight: u25,
      description: "Training programs and competency development"
    })
    
    (map-set assessment-categories "compliance" {
      max-score: u100,
      weight: u15,
      description: "Regulatory compliance and adherence"
    })
    
    (map-set assessment-categories "culture" {
      max-score: u100,
      weight: u15,
      description: "Overall safety culture and behaviors"
    })
    
    (ok true)))

;; Read-only Functions

;; Get Organization Details
(define-read-only (get-organization (organization-id uint))
  (map-get? organizations organization-id))

;; Get Assessment Details
(define-read-only (get-assessment (assessment-id uint))
  (map-get? assessments assessment-id))

;; Get Assessment History
(define-read-only (get-assessment-history (organization-id uint) (assessment-id uint))
  (map-get? assessment-history { organization-id: organization-id, assessment-id: assessment-id }))

;; Get Assessment Category
(define-read-only (get-assessment-category (category (string-ascii 30)))
  (map-get? assessment-categories category))

;; Check if Authorized Assessor
(define-read-only (is-authorized-assessor (assessor principal))
  (default-to false (map-get? authorized-assessors assessor)))

;; Get Current Counters
(define-read-only (get-counters)
  {
    assessment-counter: (var-get assessment-counter),
    organization-counter: (var-get organization-counter)
  })

;; Calculate Overall Culture Health Score
(define-read-only (calculate-culture-health (organization-id uint))
  (let
    ((org (map-get? organizations organization-id)))
    (if (is-some org)
      (ok "Healthy")  ;; Simplified for this example
      ERR-ORGANIZATION-NOT-FOUND)))
