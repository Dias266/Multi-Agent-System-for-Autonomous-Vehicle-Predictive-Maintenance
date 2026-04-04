// =============================================================================
// vehicle_agent.asl — VehicleAgent STUB
// =============================================================================
// Owner : Danial
// This stub allows the MAS to compile and run so Dias can test the
// FleetCoordinatorAgent independently without Danial's full implementation.
//
// Replace this file with Danial's full implementation when integrating.
// =============================================================================

// Initial beliefs
vin(unknown).
health_status(engine, 0.5).
urgency_level(low).

// Initial goals
!start.

// Startup: register with coordinator and fetch ML insights
+!start
    <- .my_name(Me);
       .print("[VehicleAgent:", Me, "] Starting up (stub).");
       registerVehicle(Me);
       fetchMLHealthInsights;
       !assess_health.

// Simple health check stub
+!assess_health
    :  urgency_level(high)
    <- .print("[VehicleAgent] High urgency — sending request to coordinator.");
       .send(fleet_coordinator_agent, tell, request_received(self, high)).

+!assess_health
    :  urgency_level(critical)
    <- .print("[VehicleAgent] CRITICAL urgency — sending request to coordinator.");
       .send(fleet_coordinator_agent, tell, request_received(self, critical)).

+!assess_health
    <- .print("[VehicleAgent] Health OK — no request needed.").

// React to fleet-wide alerts from coordinator
+fleet_anomaly_alert(AnomalyType, Count)
    <- .print("[VehicleAgent] Fleet alert received: ", AnomalyType,
              " across ", Count, " vehicles. Reassessing...").

// React to booking_pressure broadcasts
+booking_pressure(critical)
    <- .print("[VehicleAgent] Pressure CRITICAL — holding request.").

+booking_pressure(Level)
    <- .print("[VehicleAgent] Pressure updated: ", Level).

// Failure fallback
-!X <- .print("[VehicleAgent] Plan failed: ", X).
