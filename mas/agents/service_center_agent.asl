// =============================================================================
// service_center_agent.asl — ServiceCenterAgent STUB
// =============================================================================
// Owner : Mary
// This stub allows the MAS to compile and run so Dias can test the
// FleetCoordinatorAgent independently without Mary's full implementation.
//
// Replace this file with Mary's full implementation when integrating.
// =============================================================================

// Initial beliefs
available_slot(slot1, available).
available_slot(slot2, available).
parts_inventory(brake_pad, 5).
parts_inventory(oil_filter, 3).

// Initial goal
!start.

+!start
    <- .print("[ServiceCenterAgent] Online (stub) — awaiting requests.").

// Accept booking requests from VehicleAgents
+booking_request(VehicleID, Urgency)
    <- .print("[ServiceCenterAgent] Request from ", VehicleID,
              " urgency=", Urgency, " — processing...");
       !confirm_booking(VehicleID).

+!confirm_booking(VehicleID)
    <- .print("[ServiceCenterAgent] Confirmed booking for ", VehicleID);
       writeServiceRecord(VehicleID, "scheduled_maintenance");
       .send(VehicleID, tell, booking_confirmed(VehicleID)).

// Receive overload warnings from FleetCoordinator
+fleet_overload_warning(Level)
    <- .print("[ServiceCenterAgent] Overload warning from coordinator: ", Level).

// Receive fleet status updates
+fleet_status(Size, Pressure)
    <- .print("[ServiceCenterAgent] Fleet status — size=", Size,
              " pressure=", Pressure).

// Failure fallback
-!X <- .print("[ServiceCenterAgent] Plan failed: ", X).
