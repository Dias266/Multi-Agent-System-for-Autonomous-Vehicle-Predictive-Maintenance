// =============================================================================
// vehicle_agent.asl — Full VehicleAgent Implementation
// =============================================================================
// Owner : Danial
// Fully integrated with Edge IoT, Machine Learning Assets, and Stigmergy Signalling.
// =============================================================================

/* Initial beliefs */
vin("XYZ1234567890").          // Standardized format derived from digital twin
mileage(0).                    // Initial simulated OBD-II mileage
current_temperature(25.0).     // Initial edge sensor reading 
engine_status(ok).
battery_condition(good).
brake_condition(good).         // Key predictor for Random Forest classifier
reported_issues(0).            // High-weight ML feature

// System state tracking
urgency_level(low).
is_registered(false).
booking_status(none).          // tracks: none, requested, confirmed, deferred

/* Initial goals */
!initialize_agent.

/* Plans */

// Startup: complete local initialization and trigger registration
+!initialize_agent
    <- .my_name(Me);
       .print("[VehicleAgent:", Me, "] Initializing internal components...");
       !register_on_blockchain.

// F1: Register vehicle twin on the permissioned Hyperledger network
+!register_on_blockchain
    :  vin(VIN) & is_registered(false)
    <- .my_name(Me);
       .print("[VehicleAgent] Registering VIN ", VIN, " on Hyperledger Fabric...");
       // Custom internal action mimicking the Node.js SDK registration call
       registerVehicle(Me, VIN); 
       +is_registered(true);
       !collect_telemetry.
       
+!register_on_blockchain
    <- .print("[VehicleAgent] Registration skipped or malformed VIN.").

// F2: Telemetry loop responding to the ESP32 FSM states & sampling cadence
+!collect_telemetry
    :  is_registered(true)
    <- .print("[VehicleAgent] Polling edge sensors via MQTT topic stream...");
       
       // Simulate telemetry gathering step
       fetchEdgeSensors(Temp, Miles);
       -+current_temperature(Temp);
       -+mileage(Miles);
       
       // Process through the ML Explainable Decision Engine inside the network
       !query_ml_insights;
       
       // Dynamic cadence calculation mimicking ESP32 FSM:
       // 5s for Normal (<30C), 2s for Warning (30C-40C), 1s for Critical (>=40C)
       !calculate_sampling_delay(Delay);
       .wait(Delay);
       !collect_telemetry.

// Adaptive sampling delays mapped from Layer 1 FSM
+!calculate_sampling_delay(5000) : current_temperature(T) & T < 30.0.
+!calculate_sampling_delay(2000) : current_temperature(T) & T >= 30.0 & T < 40.0.
+!calculate_sampling_delay(1000) : current_temperature(T) & T >= 40.0.
+!calculate_sampling_delay(5000). // Fallback safe delay

// Layer 3: Machine Learning Asset Integration (Random Forest & Isolation Forest)
+!query_ml_insights
    :  current_temperature(Temp) & mileage(Miles) & brake_condition(Brakes) & reported_issues(Issues)
    <- // Call the serialised Random Forest model asset stored on the ledger
       evaluateRandomForest(Temp, Miles, Brakes, Issues, Prediction, Confidence, Explanations);
       evaluateIsolationForest(Temp, AnomalyScore);
       
       // Log prediction analytics directly to local beliefs
       if (Prediction == 1) {
           -+urgency_level(high);
           .print("[VehicleAgent] ML Warning: Maintenance Needed! Confidence: ", Confidence);
           .print("[VehicleAgent] Explanation Trace: ", Explanations);
       } else {
           -+urgency_level(low);
       };
       
       // Incorporate Unsupervised Isolation Forest results for Byzantine validation
       if (AnomalyScore > 0.75) {
           .print("[VehicleAgent] Warning: High statistical outlier telemetry detected locally!");
           +telemetry_anomaly;
       } else {
           -telemetry_anomaly;
       };
       
       // Sign telemetry with ECDSA and broadcast to the fleet
       !sign_and_publish_mqtt(Temp, Miles, Prediction);
       !evaluate_maintenance_need.

// F3: ECDSA Cryptographic signing and publishing 
+!sign_and_publish_mqtt(T, M, Pred)
    :  vin(VIN)
    <- deriveECDSAKey(VIN, SecretKey);
       signTelemetryRecord(T, M, Pred, SecretKey, CryptographicSignature);
       // Publish at QoS level 1 to ensure delivery through Mosquitto
       .broadcast(tell, telemetry_update(VIN, T, M, Pred, CryptographicSignature)).

// Stigmergy and Adaptive Coordination Logic
+!evaluate_maintenance_need
    :  urgency_level(high) & booking_status(none)
    <- !request_fleet_booking.

+!evaluate_maintenance_need
    <- true. // Health is fine, do nothing.

// Formulate booking request adhering to global stigmergy pressure limits
+!request_fleet_booking
    :  booking_pressure(critical) & not urgency_level(critical)
    <- .print("[VehicleAgent] Stigmergy backpressure active (CRITICAL). Deferring request autonomously to reduce congestion.").

+!request_fleet_booking
    :  booking_pressure(high) & urgency_level(high)
    <- .print("[VehicleAgent] Traffic high, but health context demands scheduling. Escalating to coordinator.");
       .my_name(Me);
       -+booking_status(requested);
       .send(fleet_coordinator_agent, tell, anomaly_flagged(Me, high)).

+!request_fleet_booking
    :  booking_status(deferred) | booking_status(none)
    <- .my_name(Me);
       .print("[VehicleAgent] Sending maintenance request to FleetCoordinator.");
       -+booking_status(requested);
       .send(fleet_coordinator_agent, tell, anomaly_flagged(Me, high)).

// Reactive Plan: React to environmental booking pressure shifts (Stigmergy)
+booking_pressure(Level)
    <- .print("[VehicleAgent] Stigmergy Signal: Fleet booking pressure changed to: ", Level);
       if (Level == critical & booking_status(requested) & not urgency_level(critical)) {
           .print("[VehicleAgent] Shedding load. Relinquishing active request slot.");
           -+booking_status(deferred);
       }.

// Reactive Plan: Fleet-wide pattern notifications from coordinator
+fleet_anomaly_alert(AnomalyType, Count)
    <- .print("[VehicleAgent] Fleet alert received: ", AnomalyType, " tracking across ", Count, " units. Increasing internal polling safety bounds.");
       if (reported_issues(I)) { -+reported_issues(I + 1); }.

// Handling negotiation loops routed from FleetCoordinator & ServiceCenter
+booking_confirmed(Slot, Center)
    <- .print("[VehicleAgent] Booking SUCCESS. Confirmed at ", Center, " for slot: ", Slot);
       -+booking_status(confirmed).

+booking_deferred(AlternativeSlot, Center)
    <- .print("[VehicleAgent] Booking deferred by ", Center, ". Alternative offered: ", AlternativeSlot);
       // Autonomously accept the rescheduled asset slot
       -+booking_status(confirmed).

+booking_declined(Reason)
    <- .print("[VehicleAgent] Booking failed due to: ", Reason, ". Retrying alternative pathways.");
       -+booking_status(none);
       .wait(1000);
       !evaluate_maintenance_need.

// Failure fallback plan
-!X <- .print("[VehicleAgent] Execution error on plan step: ", X).