// =============================================================================
// vehicle_agent.asl — VehicleAgent (runnable, protocol-aligned)
// =============================================================================
// Owner : Danial
// Notes : Self-contained edge + ML + ECDSA simulation in AgentSpeak.
//         Jason ENVIRONMENT actions cannot bind result variables back into a
//         plan, so telemetry/ML values are simulated internally here. The
//         edge/ML/crypto env actions (deriveECDSAKey, signTelemetryRecord, ...)
//         are invoked only as success acknowledgements.
//
// Protocol (shared across all three agents):
//   Vehicle  -> Coordinator : book_request(Vehicle, Part, Urgency)
//   Coordinator -> Service   : booking_request(Vehicle, Part, Urgency)
//   Service  -> Vehicle      : booking_confirmed(Slot, Center)
//                              booking_deferred(AltSlot, Center)
//                              booking_declined(Reason)
//   Service  -> Coordinator  : booking_confirmed(Vehicle)
// =============================================================================

/* ---------------- Initial beliefs ---------------- */
vin("XYZ1234567890").
mileage(0).
current_temperature(25.0).
engine_status(ok).
battery_condition(good).
brake_condition(good).
reported_issues(0).

urgency_level(low).
is_registered(false).
booking_status(none).          // none | requested | confirmed
booking_pressure(low).         // updated by coordinator broadcasts (stigmergy)
service_part(oil_filter).      // part requested when booking (may switch)

/* ---------------- Initial goal ---------------- */
!initialize_agent.

/* ---------------- Startup & registration ---------------- */
+!initialize_agent
    <- .my_name(Me);
       .print("[VehicleAgent:", Me, "] Initializing internal components...");
       !register_on_blockchain.

// F1: Register the vehicle digital twin on the permissioned network
+!register_on_blockchain
    :  vin(VIN) & is_registered(false)
    <- .my_name(Me);
       .print("[VehicleAgent:", Me, "] Registering VIN ", VIN, " on Hyperledger Fabric...");
       registerVehicle(Me, VIN);
       -+is_registered(true);
       !collect_telemetry.

+!register_on_blockchain
    <- .print("[VehicleAgent] Registration skipped or malformed VIN.").

/* ---------------- Telemetry / ML / signing loop ---------------- */
+!collect_telemetry
    :  is_registered(true)
    <- !sense_edge;
       !classify_health;
       !sign_and_publish;
       !evaluate_maintenance_need;
       !calculate_sampling_delay(Delay);
       .wait(Delay);
       !collect_telemetry.

// Simulated DS18B20 temperature + OBD-II mileage acquisition
+!sense_edge
    <- .random(R);
       T = 25.0 + (R * 25.0);          // 25.0 .. 50.0 C
       -+current_temperature(T);
       ?mileage(M);
       NM = M + 100;
       -+mileage(NM).

// Mock Random Forest (maintenance need) + Isolation Forest (anomaly) decisions
+!classify_health
    :  current_temperature(T) & reported_issues(I)
    <- if (T >= 40.0 | I > 0) {
           -+urgency_level(high);
           .print("[VehicleAgent] ML: maintenance needed (T=", T, ", issues=", I, ").")
       } else {
           -+urgency_level(low)
       };
       if (T >= 45.0) {
           -+telemetry_anomaly(true);
           .print("[VehicleAgent] Isolation Forest: statistical outlier telemetry (T=", T, ").")
       }.

// F3: ECDSA signing + MQTT publish (env actions acknowledge success only)
+!sign_and_publish
    :  vin(VIN) & current_temperature(T) & mileage(M) & urgency_level(U)
    <- .my_name(Me);
       deriveECDSAKey(VIN, key);
       signTelemetryRecord(T, M, U, key, sig);
       .print("[VehicleAgent:", Me, "] Published signed telemetry (T=", T,
              ", mileage=", M, ", urgency=", U, ").").

// Adaptive sampling cadence mapped from the Layer-1 ESP32 FSM
+!calculate_sampling_delay(5000) : current_temperature(T) & T < 30.0.
+!calculate_sampling_delay(2000) : current_temperature(T) & T >= 30.0 & T < 40.0.
+!calculate_sampling_delay(1000) : current_temperature(T) & T >= 40.0.
+!calculate_sampling_delay(5000).      // safe fallback

/* ---------------- Stigmergy-aware booking ---------------- */
+!evaluate_maintenance_need
    :  urgency_level(high) & booking_status(none)
    <- !request_fleet_booking.

+!evaluate_maintenance_need
    <- true.                            // health fine, or already requested

// Defer autonomously under critical backpressure (load shedding)
+!request_fleet_booking
    :  booking_pressure(critical) & not urgency_level(critical)
    <- .print("[VehicleAgent] Critical backpressure — deferring request to reduce congestion.").

// Otherwise send a booking request to the FleetCoordinator
+!request_fleet_booking
    :  service_part(P)
    <- .my_name(Me);
       .print("[VehicleAgent:", Me, "] Sending book_request to FleetCoordinator (part=", P, ").");
       -+booking_status(requested);
       .send(fleet_coordinator_agent, tell, book_request(Me, P, high)).

/* ---------------- Reactive coordination plans ---------------- */
// Stigmergy signal: fleet booking pressure changed
+booking_pressure(Level)
    <- .print("[VehicleAgent] Stigmergy signal: booking pressure = ", Level).

// Fleet-wide brake_wear pattern -> prioritise brake service
+fleet_anomaly_alert(brake_wear, Count)
    <- .print("[VehicleAgent] Fleet brake_wear pattern across ", Count,
              " units. Prioritising brake service.");
       -+service_part(brake_pad);
       ?reported_issues(I);
       -+reported_issues(I + 1).

// Any other fleet-wide anomaly pattern
+fleet_anomaly_alert(AnomalyType, Count)
    <- .print("[VehicleAgent] Fleet alert: ", AnomalyType, " across ", Count, " units.");
       ?reported_issues(I);
       -+reported_issues(I + 1).

// Booking outcomes from the ServiceCenter
+booking_confirmed(Slot, Center)
    <- .print("[VehicleAgent] Booking CONFIRMED at ", Center, " slot ", Slot, ".");
       -+booking_status(confirmed).

+booking_deferred(AltSlot, Center)
    <- .print("[VehicleAgent] Booking deferred by ", Center,
              " — alternative slot ", AltSlot, " accepted.");
       -+booking_status(confirmed).

+booking_declined(Reason)
    <- .print("[VehicleAgent] Booking declined: ", Reason, ". Will retry on next cycle.");
       -+booking_status(none).

/* ---------------- Failure fallback ---------------- */
-!X
    <- .print("[VehicleAgent] Plan failure on: ", X).
