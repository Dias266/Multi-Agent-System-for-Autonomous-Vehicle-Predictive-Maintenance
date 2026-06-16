// =============================================================================
// vehicle_agent.asl — Cleaned & Fixed VehicleAgent Implementation
// =============================================================================

/* Initial beliefs */
vin("XYZ1234567890").          
mileage(0).                    
current_temperature(25.0).     
engine_status(ok).
battery_condition(good).
brake_condition(good).         
reported_issues(0).            

system_state_tracking.
urgency_level(low).
is_registered(false).
booking_status(none).          

/* Initial goals */
!initialize_agent.

/* Plans */

+!initialize_agent
    <- .my_name(Me);
       .print("[VehicleAgent:", Me, "] Initializing internal components...");
       !register_on_blockchain.

+!register_on_blockchain
    :  vin(VIN) & is_registered(false)
    <- .my_name(Me);
       .print("[VehicleAgent] Registering VIN ", VIN, " on Hyperledger Fabric...");
       registerVehicle(Me, VIN); 
       +is_registered(true);
       !collect_telemetry.
       
+!register_on_blockchain
    <- .print("[VehicleAgent] Registration skipped or malformed VIN.").

+!collect_telemetry
    :  is_registered(true)
    <- .print("[VehicleAgent] Polling edge sensors via MQTT topic stream...");
       fetchEdgeSensors(Temp, Miles);
       -+current_temperature(Temp);
       -+mileage(Miles);
       
       !query_ml_insights;
       
       !calculate_sampling_delay(Delay);
       .wait(Delay);
       !collect_telemetry.

+!calculate_sampling_delay(5000) : current_temperature(T) & T < 30.0.
+!calculate_sampling_delay(2000) : current_temperature(T) & T >= 30.0 & T < 40.0.
+!calculate_sampling_delay(1000) : current_temperature(T) & T >= 40.0.
+!calculate_sampling_delay(5000). 

+!query_ml_insights
    :  current_temperature(Temp) & mileage(Miles) & brake_condition(Brakes) & reported_issues(Issues)
    <- evaluateRandomForest(Temp, Miles, Brakes, Issues, Prediction, Confidence, Explanations);
       evaluateIsolationForest(Temp, AnomalyScore);
       
       if (Prediction == 1) {
           -+urgency_level(high);
           .print("[VehicleAgent] ML Warning: Maintenance Needed! Confidence: ", Confidence);
           .print("[VehicleAgent] Explanation Trace: ", Explanations);
       } else {
           -+urgency_level(low);
       };
       
       // FIXED: Unified anomaly logic. Do not bypass the evaluation goal or hardcode wrong terms.
       if (AnomalyScore > 0.75) {
           .print("[VehicleAgent] Warning: High statistical outlier telemetry detected locally!");
           +telemetry_anomaly;
           -+urgency_level(high); // Elevate urgency to trigger the booking system downstream safely
       } else {
           -telemetry_anomaly;
       };

       !sign_and_publish_mqtt(Temp, Miles, Prediction);
       !evaluate_maintenance_need.

+!sign_and_publish_mqtt(T, M, Pred)
    :  vin(VIN)
    <- deriveECDSAKey(VIN, SecretKey);
       signTelemetryRecord(T, M, Pred, SecretKey, CryptographicSignature);
       .broadcast(tell, telemetry_update(VIN, T, M, Pred, CryptographicSignature)).

+!evaluate_maintenance_need
    :  urgency_level(high) & booking_status(none)
    <- .print("[VehicleAgent] evaluate_maintenance_need triggered due to high urgency.");
       !request_fleet_booking.

+!evaluate_maintenance_need
    <- true. 

// Formulate booking request adhering to global stigmergy pressure limits
+!request_fleet_booking
    :  booking_pressure(critical) & not urgency_level(critical)
    <- .print("[VehicleAgent] Stigmergy backpressure active (CRITICAL). Deferring request autonomously to reduce congestion.").

+!request_fleet_booking
    :  booking_pressure(high) & urgency_level(high)
    <- .print("[VehicleAgent] Traffic high, but health context demands scheduling. Escalating to coordinator.");
       .my_name(Me);
       -+booking_status(requested);
       // FIXED: Passing Atom 'Me' instead of String "vehicle", matching the internal structure.
       .send(fleet_coordinator_agent, tell, book_request(Me, brake_pad, high)). 

+!request_fleet_booking
    :  booking_status(deferred) | booking_status(none)
    <- .my_name(Me);
       .print("[VehicleAgent] Sending maintenance request to FleetCoordinator.");
       -+booking_status(requested);
       // FIXED: Consistency in message structure
       .send(fleet_coordinator_agent, tell, book_request(Me, brake_pad, high)).

+booking_pressure(Level)
    <- .print("[VehicleAgent] Stigmergy Signal: Fleet booking pressure changed to: ", Level);
       if (Level == critical & booking_status(requested) & not urgency_level(critical)) {
           .print("[VehicleAgent] Shedding load. Relinquishing active request slot.");
           -+booking_status(deferred);
       }.

+fleet_anomaly_alert(AnomalyType, Count)
    <- .print("[VehicleAgent] Fleet alert received: ", AnomalyType, " tracking across ", Count, " units. Increasing internal polling safety bounds.");
       if (reported_issues(I)) { -+reported_issues(I + 1); }.

+booking_confirmed(Slot, Center)
    <- .print("[VehicleAgent] Booking SUCCESS. Confirmed at ", Center, " for slot: ", Slot);
       -+booking_status(confirmed).

+booking_deferred(AlternativeSlot, Center)
    <- .print("[VehicleAgent] Booking deferred by ", Center, ". Alternative offered: ", AlternativeSlot);
       -+booking_status(confirmed).

+booking_declined(Reason)
    <- .print("[VehicleAgent] Booking failed due to: ", Reason, ". Retrying alternative pathways.");
       -+booking_status(none);
       .wait(1000);
       !evaluate_maintenance_need.

-!X <- .print("[VehicleAgent] Execution error on plan step: ", X).