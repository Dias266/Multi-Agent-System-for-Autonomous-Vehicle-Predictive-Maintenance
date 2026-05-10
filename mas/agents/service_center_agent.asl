// =============================================================================
// service_center_agent.asl — ServiceCenterAgent
// =============================================================================
// ISE Project: Multi-Agent System for Autonomous Vehicle Predictive Maintenance
// Integrated: Slot Management and Inventory Control
// =============================================================================

// ---------------------------------------------------------------------------
// INITIAL BELIEFS
// ---------------------------------------------------------------------------

// Resources
available_slot(slot1, available).
available_slot(slot2, available).
available_slot(slot3, available).

parts_inventory(brake_pad, 10).
parts_inventory(oil_filter, 10).

// State
is_overloaded(false).

// ---------------------------------------------------------------------------
// INITIAL GOALS
// ---------------------------------------------------------------------------

!start.

// ---------------------------------------------------------------------------
// PLANS: STARTUP
// ---------------------------------------------------------------------------

+!start
    <- .print("[ServiceCenterAgent] Operational. Ready for maintenance requests.").

// ---------------------------------------------------------------------------
// PLANS: HANDLING REQUESTS
// ---------------------------------------------------------------------------

// Triggered when a VehicleAgent sends a booking_request
+booking_request(VehicleID, Urgency)
    <- .print("[ServiceCenterAgent] Received request from ", VehicleID, " (Urgency: ", Urgency, ")");
       !evaluate_request(VehicleID, Urgency).

// 1. Success Case: Slot and Parts are available
+!evaluate_request(VehicleID, Urgency)
    :  available_slot(SlotID, available) & parts_inventory(oil_filter, Qty) & Qty > 0
    <- .print("[ServiceCenterAgent] Resources found. Allocating ", SlotID, " to ", VehicleID);
       !perform_booking(VehicleID, SlotID).

// 2. Failure Case: No slots available
+!evaluate_request(VehicleID, Urgency)
    :  not available_slot(_, available)
    <- .print("[ServiceCenterAgent] REJECTED: No slots available for ", VehicleID);
       .send(VehicleID, tell, booking_rejected(no_slots)).

// 3. Failure Case: No parts available
+!evaluate_request(VehicleID, Urgency)
    :  parts_inventory(oil_filter, 0)
    <- .print("[ServiceCenterAgent] REJECTED: Out of stock for oil filters.");
       .send(VehicleID, tell, booking_rejected(out_of_parts)).

// ---------------------------------------------------------------------------
// PLANS: BOOKING & RESOURCE UPDATES
// ---------------------------------------------------------------------------
+!perform_booking(VehicleID, SlotID)
    <- .print("[ServiceCenterAgent] DEBUG: Attempting to update beliefs for ", VehicleID);
       -+available_slot(SlotID, occupied);
       
       // Comment out the Java action if you aren't sure it's linked yet
       // writeServiceRecord(VehicleID, "scheduled_maintenance");
       
       .send(VehicleID, tell, booking_confirmed(SlotID));
       .print("[ServiceCenterAgent] DEBUG: Successfully confirmed ", VehicleID);
       
       .wait(2000); 
       !release_slot(SlotID).
       
+!release_slot(SlotID)
    <- -+available_slot(SlotID, available);
       .print("[ServiceCenterAgent] ", SlotID, " is now free.").

// ---------------------------------------------------------------------------
// PLANS: COORDINATION & OVERLOAD
// ---------------------------------------------------------------------------

// Reacting to the FleetCoordinator's warning
+fleet_overload_warning(Level)
    <- -+is_overloaded(true);
       .print("[ServiceCenterAgent] High fleet pressure alert: ", Level, ". Switching to emergency-only mode.").

+fleet_status(Size, Pressure)
    <- .print("[ServiceCenterAgent] Fleet Status Report — Vehicles: ", Size, " System Pressure: ", Pressure).

// ---------------------------------------------------------------------------
// PLANS: FAILURE FALLBACK
// ---------------------------------------------------------------------------

-!X[error(E), error_msg(Msg)]
    <- .print("[ServiceCenterAgent] Plan failed: ", X, " (", Msg, ")").