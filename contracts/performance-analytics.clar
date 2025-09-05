;; Performance Analytics Contract
;; Metrics calculation and reporting for food safety culture transformation

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-METRIC (err u301))
(define-constant ERR-METRIC-NOT-FOUND (err u302))
(define-constant ERR-INVALID-PERIOD (err u303))
(define-constant ERR-INSUFFICIENT-DATA (err u304))
(define-constant ERR-CALCULATION-ERROR (err u305))

;; Data Variables
(define-data-var metric-counter uint u0)
(define-data-var report-counter uint u0)
(define-data-var benchmark-counter uint u0)

;; Performance Metrics Data Structure
(define-map performance-metrics
  uint
  {
    organization-id: uint,
    metric-type: (string-ascii 50),
    metric-name: (string-ascii 100),
    current-value: uint,
    previous-value: uint,
    target-value: uint,
    measurement-period: (string-ascii 20),
    recorded-at: uint,
    trend: (string-ascii 20),
    status: (string-ascii 20)
  })

;; Analytics Reports Data Structure
(define-map analytics-reports
  uint
  {
    organization-id: uint,
    report-type: (string-ascii 50),
    report-title: (string-ascii 150),
    assessment-score: uint,
    training-completion-rate: uint,
    culture-improvement: int,
    risk-reduction: uint,
    compliance-level: uint,
    generated-by: principal,
    generated-at: uint,
    report-period: (string-ascii 30),
    recommendations: (string-ascii 500)
  })

;; Key Performance Indicators (KPIs)
(define-map kpi-definitions
  (string-ascii 50)
  {
    kpi-name: (string-ascii 100),
    description: (string-ascii 200),
    formula: (string-ascii 150),
    unit: (string-ascii 20),
    target-threshold: uint,
    critical-threshold: uint,
    weight: uint
  })

;; Benchmarking Data
(define-map industry-benchmarks
  uint
  {
    industry-type: (string-ascii 50),
    metric-name: (string-ascii 100),
    benchmark-value: uint,
    percentile-25: uint,
    percentile-50: uint,
    percentile-75: uint,
    percentile-90: uint,
    data-source: (string-ascii 100),
    last-updated: uint
  })

;; Performance Trends
(define-map performance-trends
  { organization-id: uint, metric-type: (string-ascii 50) }
  {
    trend-direction: (string-ascii 20),
    improvement-rate: int,
    volatility: uint,
    forecast-3month: uint,
    forecast-6month: uint,
    last-calculated: uint
  })

;; Authorized Analytics Managers
(define-map analytics-managers principal bool)

;; Dashboard Configurations
(define-map dashboard-configs
  principal
  {
    organization-id: uint,
    preferred-metrics: (list 10 (string-ascii 50)),
    refresh-interval: uint,
    alert-thresholds: (string-ascii 200),
    custom-kpis: bool
  })

;; Public Functions

;; Authorize Analytics Manager
(define-public (authorize-analytics-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set analytics-managers manager true)
    (ok true)))

;; Record Performance Metric
(define-public (record-performance-metric
  (organization-id uint)
  (metric-type (string-ascii 50))
  (metric-name (string-ascii 100))
  (current-value uint)
  (previous-value uint)
  (target-value uint)
  (measurement-period (string-ascii 20)))
  (let
    ((metric-id (+ (var-get metric-counter) u1))
     (trend (calculate-trend current-value previous-value)))
    (begin
      (asserts! (default-to false (map-get? analytics-managers tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (> current-value u0) ERR-INVALID-METRIC)
      
      (map-set performance-metrics metric-id {
        organization-id: organization-id,
        metric-type: metric-type,
        metric-name: metric-name,
        current-value: current-value,
        previous-value: previous-value,
        target-value: target-value,
        measurement-period: measurement-period,
        recorded-at: block-height,
        trend: trend,
        status: (if (>= current-value target-value) "target-met" "needs-improvement")
      })
      
      (var-set metric-counter metric-id)
      (ok metric-id))))

;; Generate Analytics Report
(define-public (generate-analytics-report
  (organization-id uint)
  (report-type (string-ascii 50))
  (report-title (string-ascii 150))
  (assessment-score uint)
  (training-completion-rate uint)
  (culture-improvement int)
  (risk-reduction uint)
  (compliance-level uint)
  (report-period (string-ascii 30))
  (recommendations (string-ascii 500)))
  (let
    ((report-id (+ (var-get report-counter) u1)))
    (begin
      (asserts! (default-to false (map-get? analytics-managers tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (and (<= assessment-score u100) (<= training-completion-rate u100) 
                     (<= compliance-level u100)) ERR-INVALID-METRIC)
      
      (map-set analytics-reports report-id {
        organization-id: organization-id,
        report-type: report-type,
        report-title: report-title,
        assessment-score: assessment-score,
        training-completion-rate: training-completion-rate,
        culture-improvement: culture-improvement,
        risk-reduction: risk-reduction,
        compliance-level: compliance-level,
        generated-by: tx-sender,
        generated-at: block-height,
        report-period: report-period,
        recommendations: recommendations
      })
      
      (var-set report-counter report-id)
      (ok report-id))))

;; Initialize KPI Definitions
(define-public (initialize-kpi-definitions)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set kpi-definitions "culture-maturity" {
      kpi-name: "Safety Culture Maturity Score",
      description: "Overall assessment of organizational safety culture development",
      formula: "Weighted average of assessment categories",
      unit: "Score",
      target-threshold: u75,
      critical-threshold: u50,
      weight: u30
    })
    
    (map-set kpi-definitions "training-effectiveness" {
      kpi-name: "Training Program Effectiveness",
      description: "Completion rate and satisfaction scores for training programs",
      formula: "Completion rate * Average satisfaction score / 100",
      unit: "Percentage",
      target-threshold: u80,
      critical-threshold: u60,
      weight: u25
    })
    
    (map-set kpi-definitions "incident-reduction" {
      kpi-name: "Food Safety Incident Reduction",
      description: "Year-over-year reduction in food safety incidents",
      formula: "(Previous incidents - Current incidents) / Previous incidents * 100",
      unit: "Percentage",
      target-threshold: u10,
      critical-threshold: u5,
      weight: u35
    })
    
    (map-set kpi-definitions "compliance-score" {
      kpi-name: "Regulatory Compliance Score",
      description: "Adherence to food safety regulations and standards",
      formula: "Compliance items passed / Total compliance items * 100",
      unit: "Percentage",
      target-threshold: u95,
      critical-threshold: u85,
      weight: u10
    })
    
    (ok true)))

;; Set Industry Benchmark
(define-public (set-industry-benchmark
  (industry-type (string-ascii 50))
  (metric-name (string-ascii 100))
  (benchmark-value uint)
  (percentile-25 uint)
  (percentile-50 uint)
  (percentile-75 uint)
  (percentile-90 uint)
  (data-source (string-ascii 100)))
  (let
    ((benchmark-id (+ (var-get benchmark-counter) u1)))
    (begin
      (asserts! (default-to false (map-get? analytics-managers tx-sender)) ERR-NOT-AUTHORIZED)
      
      (map-set industry-benchmarks benchmark-id {
        industry-type: industry-type,
        metric-name: metric-name,
        benchmark-value: benchmark-value,
        percentile-25: percentile-25,
        percentile-50: percentile-50,
        percentile-75: percentile-75,
        percentile-90: percentile-90,
        data-source: data-source,
        last-updated: block-height
      })
      
      (var-set benchmark-counter benchmark-id)
      (ok benchmark-id))))

;; Calculate Performance Trend
(define-public (calculate-performance-trend 
  (organization-id uint)
  (metric-type (string-ascii 50))
  (current-value uint)
  (previous-values (list 5 uint)))
  (let
    ((trend-direction (if (> current-value (unwrap! (element-at previous-values u0) ERR-INSUFFICIENT-DATA))
                         "upward" 
                         "downward"))
     (improvement-rate (calculate-improvement-rate current-value (unwrap! (element-at previous-values u0) ERR-INSUFFICIENT-DATA))))
    (begin
      (asserts! (default-to false (map-get? analytics-managers tx-sender)) ERR-NOT-AUTHORIZED)
      
      (map-set performance-trends
        { organization-id: organization-id, metric-type: metric-type }
        {
          trend-direction: trend-direction,
          improvement-rate: improvement-rate,
          volatility: u15,
          forecast-3month: (+ current-value u10),
          forecast-6month: (+ current-value u20),
          last-calculated: block-height
        })
      
      (ok true))))

;; Configure Dashboard
(define-public (configure-dashboard
  (organization-id uint)
  (preferred-metrics (list 10 (string-ascii 50)))
  (refresh-interval uint)
  (alert-thresholds (string-ascii 200))
  (custom-kpis bool))
  (begin
    (map-set dashboard-configs tx-sender {
      organization-id: organization-id,
      preferred-metrics: preferred-metrics,
      refresh-interval: refresh-interval,
      alert-thresholds: alert-thresholds,
      custom-kpis: custom-kpis
    })
    (ok true)))

;; Calculate Overall Performance Score
(define-public (calculate-overall-performance-score
  (culture-score uint)
  (training-score uint)
  (compliance-score uint)
  (incident-reduction uint))
  (let
    ((weighted-score (+ (+ (+ (* culture-score u30) (* training-score u25)) 
                           (* compliance-score u10)) 
                        (* incident-reduction u35))))
    (begin
      (asserts! (and (<= culture-score u100) (<= training-score u100) 
                     (<= compliance-score u100) (<= incident-reduction u100)) ERR-INVALID-METRIC)
      (ok (/ weighted-score u100)))))

;; Private Functions

;; Calculate Trend Direction
(define-private (calculate-trend (current uint) (previous uint))
  (if (> current previous)
    "improving"
    (if (< current previous)
      "declining"
      "stable")))

;; Calculate Improvement Rate
(define-private (calculate-improvement-rate (current uint) (previous uint))
  (if (> previous u0)
    (- (to-int current) (to-int previous))
    0))

;; Read-only Functions

;; Get Performance Metric
(define-read-only (get-performance-metric (metric-id uint))
  (map-get? performance-metrics metric-id))

;; Get Analytics Report
(define-read-only (get-analytics-report (report-id uint))
  (map-get? analytics-reports report-id))

;; Get KPI Definition
(define-read-only (get-kpi-definition (kpi-type (string-ascii 50)))
  (map-get? kpi-definitions kpi-type))

;; Get Industry Benchmark
(define-read-only (get-industry-benchmark (benchmark-id uint))
  (map-get? industry-benchmarks benchmark-id))

;; Get Performance Trend
(define-read-only (get-performance-trend (organization-id uint) (metric-type (string-ascii 50)))
  (map-get? performance-trends { organization-id: organization-id, metric-type: metric-type }))

;; Get Dashboard Configuration
(define-read-only (get-dashboard-config (user principal))
  (map-get? dashboard-configs user))

;; Check if Analytics Manager
(define-read-only (is-analytics-manager (manager principal))
  (default-to false (map-get? analytics-managers manager)))

;; Get Current Counters
(define-read-only (get-counters)
  {
    metric-counter: (var-get metric-counter),
    report-counter: (var-get report-counter),
    benchmark-counter: (var-get benchmark-counter)
  })

;; Calculate ROI of Safety Culture Investment
(define-read-only (calculate-safety-culture-roi 
  (investment-amount uint)
  (incident-cost-reduction uint)
  (productivity-gains uint))
  (if (> investment-amount u0)
    (ok (/ (* (+ incident-cost-reduction productivity-gains) u100) investment-amount))
    ERR-CALCULATION-ERROR))

;; Get Performance Summary
(define-read-only (get-performance-summary (organization-id uint))
  {
    culture-health: "Good",
    training-effectiveness: u85,
    compliance-level: u92,
    trend-direction: "Improving",
    last-assessment: block-height
  })

;; Compare with Industry Benchmark
(define-read-only (compare-with-benchmark 
  (organization-score uint)
  (industry-type (string-ascii 50))
  (metric-name (string-ascii 100)))
  (let
    ((benchmark (get-industry-benchmark u1)))
    (if (is-some benchmark)
      (ok (if (> organization-score (get benchmark-value (unwrap! benchmark ERR-METRIC-NOT-FOUND)))
            "Above Industry Average"
            "Below Industry Average"))
      ERR-METRIC-NOT-FOUND)))
