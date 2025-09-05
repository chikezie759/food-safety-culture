;; Training Management Contract
;; Development and tracking of food safety awareness programs

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-TRAINING (err u201))
(define-constant ERR-TRAINING-NOT-FOUND (err u202))
(define-constant ERR-PARTICIPANT-NOT-FOUND (err u203))
(define-constant ERR-ALREADY-ENROLLED (err u204))
(define-constant ERR-TRAINING-COMPLETED (err u205))
(define-constant ERR-INVALID-SCORE (err u206))
(define-constant ERR-TRAINING-NOT-STARTED (err u207))

;; Data Variables
(define-data-var training-counter uint u0)
(define-data-var module-counter uint u0)
(define-data-var enrollment-counter uint u0)

;; Training Programs Data Structure
(define-map training-programs
  uint
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    duration-hours: uint,
    difficulty-level: (string-ascii 20),
    created-by: principal,
    created-at: uint,
    status: (string-ascii 20),
    max-participants: uint,
    current-participants: uint,
    passing-score: uint
  })

;; Training Modules Data Structure
(define-map training-modules
  uint
  {
    training-id: uint,
    module-name: (string-ascii 100),
    content-url: (string-ascii 200),
    duration-minutes: uint,
    learning-objectives: (string-ascii 400),
    assessment-required: bool,
    module-order: uint
  })

;; Participant Enrollments
(define-map enrollments
  uint
  {
    training-id: uint,
    participant: principal,
    enrolled-at: uint,
    status: (string-ascii 20),
    progress-percentage: uint,
    completion-date: (optional uint),
    final-score: (optional uint),
    certificate-issued: bool
  })

;; Training Completions
(define-map training-completions
  { participant: principal, training-id: uint }
  {
    completion-date: uint,
    final-score: uint,
    time-spent: uint,
    certificate-id: (string-ascii 50),
    feedback-rating: uint,
    improvement-areas: (string-ascii 300)
  })

;; Training Statistics
(define-map training-statistics
  uint
  {
    total-enrollments: uint,
    total-completions: uint,
    average-score: uint,
    completion-rate: uint,
    average-rating: uint,
    last-updated: uint
  })

;; Authorized Training Managers
(define-map training-managers principal bool)

;; Training Categories Configuration
(define-map training-categories
  (string-ascii 50)
  {
    name: (string-ascii 100),
    description: (string-ascii 200),
    mandatory: bool,
    renewal-period: uint,
    competency-weight: uint
  })

;; Public Functions

;; Authorize Training Manager
(define-public (authorize-training-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set training-managers manager true)
    (ok true)))

;; Create Training Program
(define-public (create-training-program
  (title (string-ascii 100))
  (description (string-ascii 500))
  (category (string-ascii 50))
  (duration-hours uint)
  (difficulty-level (string-ascii 20))
  (max-participants uint)
  (passing-score uint))
  (let
    ((training-id (+ (var-get training-counter) u1)))
    (begin
      (asserts! (default-to false (map-get? training-managers tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (and (> duration-hours u0) (<= passing-score u100)) ERR-INVALID-TRAINING)
      
      (map-set training-programs training-id {
        title: title,
        description: description,
        category: category,
        duration-hours: duration-hours,
        difficulty-level: difficulty-level,
        created-by: tx-sender,
        created-at: block-height,
        status: "active",
        max-participants: max-participants,
        current-participants: u0,
        passing-score: passing-score
      })
      
      (map-set training-statistics training-id {
        total-enrollments: u0,
        total-completions: u0,
        average-score: u0,
        completion-rate: u0,
        average-rating: u0,
        last-updated: block-height
      })
      
      (var-set training-counter training-id)
      (ok training-id))))

;; Add Training Module
(define-public (add-training-module
  (training-id uint)
  (module-name (string-ascii 100))
  (content-url (string-ascii 200))
  (duration-minutes uint)
  (learning-objectives (string-ascii 400))
  (assessment-required bool)
  (module-order uint))
  (let
    ((module-id (+ (var-get module-counter) u1))
     (training (map-get? training-programs training-id)))
    (begin
      (asserts! (default-to false (map-get? training-managers tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (is-some training) ERR-TRAINING-NOT-FOUND)
      
      (map-set training-modules module-id {
        training-id: training-id,
        module-name: module-name,
        content-url: content-url,
        duration-minutes: duration-minutes,
        learning-objectives: learning-objectives,
        assessment-required: assessment-required,
        module-order: module-order
      })
      
      (var-set module-counter module-id)
      (ok module-id))))

;; Enroll in Training
(define-public (enroll-in-training (training-id uint))
  (let
    ((enrollment-id (+ (var-get enrollment-counter) u1))
     (training (map-get? training-programs training-id))
     (current-count (get current-participants (unwrap! training ERR-TRAINING-NOT-FOUND))))
    (begin
      (asserts! (is-some training) ERR-TRAINING-NOT-FOUND)
      (asserts! (< current-count (get max-participants (unwrap! training ERR-TRAINING-NOT-FOUND))) ERR-INVALID-TRAINING)
      
      (map-set enrollments enrollment-id {
        training-id: training-id,
        participant: tx-sender,
        enrolled-at: block-height,
        status: "enrolled",
        progress-percentage: u0,
        completion-date: none,
        final-score: none,
        certificate-issued: false
      })
      
      ;; Update training participant count
      (map-set training-programs training-id
        (merge (unwrap! training ERR-TRAINING-NOT-FOUND)
               { current-participants: (+ current-count u1) }))
      
      ;; Update statistics
      (update-training-statistics training-id "enrollment")
      
      (var-set enrollment-counter enrollment-id)
      (ok enrollment-id))))

;; Update Training Progress
(define-public (update-training-progress 
  (enrollment-id uint)
  (progress-percentage uint))
  (let
    ((enrollment (map-get? enrollments enrollment-id)))
    (begin
      (asserts! (is-some enrollment) ERR-PARTICIPANT-NOT-FOUND)
      (asserts! (is-eq tx-sender (get participant (unwrap! enrollment ERR-PARTICIPANT-NOT-FOUND))) ERR-NOT-AUTHORIZED)
      (asserts! (<= progress-percentage u100) ERR-INVALID-SCORE)
      
      (map-set enrollments enrollment-id
        (merge (unwrap! enrollment ERR-PARTICIPANT-NOT-FOUND)
               { 
                 progress-percentage: progress-percentage,
                 status: (if (is-eq progress-percentage u100) "completed" "in-progress")
               }))
      (ok true))))

;; Complete Training
(define-public (complete-training 
  (enrollment-id uint)
  (final-score uint)
  (time-spent uint)
  (feedback-rating uint))
  (let
    ((enrollment (map-get? enrollments enrollment-id))
     (training-id (get training-id (unwrap! enrollment ERR-PARTICIPANT-NOT-FOUND)))
     (training (map-get? training-programs training-id))
     (passing-score (get passing-score (unwrap! training ERR-TRAINING-NOT-FOUND)))
     (participant (get participant (unwrap! enrollment ERR-PARTICIPANT-NOT-FOUND))))
    (begin
      (asserts! (is-some enrollment) ERR-PARTICIPANT-NOT-FOUND)
      (asserts! (is-eq tx-sender participant) ERR-NOT-AUTHORIZED)
      (asserts! (and (<= final-score u100) (<= feedback-rating u5)) ERR-INVALID-SCORE)
      
      ;; Update enrollment
      (map-set enrollments enrollment-id
        (merge (unwrap! enrollment ERR-PARTICIPANT-NOT-FOUND)
               { 
                 status: (if (>= final-score passing-score) "passed" "failed"),
                 progress-percentage: u100,
                 completion-date: (some block-height),
                 final-score: (some final-score),
                 certificate-issued: (>= final-score passing-score)
               }))
      
      ;; Record completion details
      (map-set training-completions
        { participant: participant, training-id: training-id }
        {
          completion-date: block-height,
          final-score: final-score,
          time-spent: time-spent,
          certificate-id: "CERT-001",
          feedback-rating: feedback-rating,
          improvement-areas: "Communication and Leadership skills"
        })
      
      ;; Update statistics
      (update-training-statistics training-id "completion")
      
      (ok (>= final-score passing-score)))))

;; Initialize Training Categories
(define-public (initialize-training-categories)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set training-categories "food-safety-basics" {
      name: "Food Safety Fundamentals",
      description: "Basic food safety principles and practices",
      mandatory: true,
      renewal-period: u365,
      competency-weight: u30
    })
    
    (map-set training-categories "leadership-development" {
      name: "Safety Leadership Development",
      description: "Leadership skills for food safety culture",
      mandatory: false,
      renewal-period: u730,
      competency-weight: u25
    })
    
    (map-set training-categories "hazard-analysis" {
      name: "Hazard Analysis and Risk Assessment",
      description: "Systematic approach to identify food safety hazards",
      mandatory: true,
      renewal-period: u365,
      competency-weight: u35
    })
    
    (ok true)))

;; Private Functions

;; Update Training Statistics
(define-private (update-training-statistics (training-id uint) (action (string-ascii 20)))
  (let
    ((stats (default-to
      { total-enrollments: u0, total-completions: u0, average-score: u0, 
        completion-rate: u0, average-rating: u0, last-updated: block-height }
      (map-get? training-statistics training-id))))
    (if (is-eq action "enrollment")
      (map-set training-statistics training-id
        (merge stats { 
          total-enrollments: (+ (get total-enrollments stats) u1),
          last-updated: block-height 
        }))
      (if (is-eq action "completion")
        (map-set training-statistics training-id
          (merge stats { 
            total-completions: (+ (get total-completions stats) u1),
            completion-rate: (/ (* (+ (get total-completions stats) u1) u100) (get total-enrollments stats)),
            last-updated: block-height 
          }))
        false))))

;; Read-only Functions

;; Get Training Program
(define-read-only (get-training-program (training-id uint))
  (map-get? training-programs training-id))

;; Get Training Module
(define-read-only (get-training-module (module-id uint))
  (map-get? training-modules module-id))

;; Get Enrollment Details
(define-read-only (get-enrollment (enrollment-id uint))
  (map-get? enrollments enrollment-id))

;; Get Training Completion
(define-read-only (get-training-completion (participant principal) (training-id uint))
  (map-get? training-completions { participant: participant, training-id: training-id }))

;; Get Training Statistics
(define-read-only (get-training-statistics (training-id uint))
  (map-get? training-statistics training-id))

;; Get Training Category
(define-read-only (get-training-category (category (string-ascii 50)))
  (map-get? training-categories category))

;; Check if Training Manager
(define-read-only (is-training-manager (manager principal))
  (default-to false (map-get? training-managers manager)))

;; Get Current Counters
(define-read-only (get-counters)
  {
    training-counter: (var-get training-counter),
    module-counter: (var-get module-counter),
    enrollment-counter: (var-get enrollment-counter)
  })

;; Calculate Training Effectiveness
(define-read-only (calculate-training-effectiveness (training-id uint))
  (let
    ((stats (map-get? training-statistics training-id)))
    (if (is-some stats)
      (ok (get completion-rate (unwrap! stats ERR-TRAINING-NOT-FOUND)))
      ERR-TRAINING-NOT-FOUND)))
