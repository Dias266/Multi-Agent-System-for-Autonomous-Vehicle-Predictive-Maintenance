// =============================================================================
// vehicle_agent.asl — Finalized VehicleAgent STUB
// =============================================================================

// Initial beliefs
health_status(engine, 0.5).
urgency_level(low). 
pending_request(false).

!start.

+!start
    <- .my_name(Me);
       .print("[VehicleAgent] ", Me, " online. Registering...");
       .send(fleet_coordinator_agent, tell, vehicle_registered(Me));
       !main_loop.

// The main loop keeps the agent active during your test scenarios
+!main_loop
    <- !assess_health;
       .wait(5000); // Wait 5 seconds between checks
       !main_loop.

+!assess_health
    :  pending_request(true)
    <- true. // Do nothing if we are already waiting for a repair

+!assess_health
    :  .my_name(Me) & (urgency_level(high) | urgency_level(critical))
    <- .print("[VehicleAgent] ", Me, " needs maintenance. Checking pressure...");
       !decide_to_send_request.

+!assess_health
    :  .my_name(Me)
    <- .print("[VehicleAgent] ", Me, " health OK.").

// --- STIGMERGY LOGIC ---

+!decide_to_send_request
    :  .my_name(Me) & booking_pressure(critical)
    <- .print("[VehicleAgent] ", Me, " sees CRITICAL pressure. Voluntary back-off active.").

+!decide_to_send_request
    :  .my_name(Me) & urgency_level(U)
    <- .print("[VehicleAgent] ", Me, " sending request (Urgency: ", U, ")");
       -+pending_request(true);
       .send(fleet_coordinator_agent, tell, request_received(Me, U));
       .send(service_center_agent, tell, booking_request(Me, U)).

// --- REACTION TO SUCCESS ---

+booking_confirmed(ID)
    :  .my_name(Me)
    <- .print("[VehicleAgent] ", Me, " repair confirmed! Resetting status.");
       .send(fleet_coordinator_agent, tell, booking_confirmed(Me));
       -+urgency_level(low);
       -+pending_request(false).

// --- REACTION TO ALERTS ---

+fleet_anomaly_alert(Type, Count)
    :  .my_name(Me)
    <- .print("[VehicleAgent] ", Me, " acknowledging fleet alert for: ", Type).