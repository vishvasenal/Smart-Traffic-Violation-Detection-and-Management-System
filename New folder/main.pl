%    Dynamic Predicates
:- dynamic current_vehicle/1.
:- dynamic current_type/1.
:- dynamic current_license/1.
:- dynamic driver_credits/1.

               %Facts 

% Pre stored 5 license numbers (8 digits)
valid_license(10000000).
valid_license(10000001).
valid_license(10000002).
valid_license(10000003).
valid_license(10000004).

% Vehicle Multipliers
vehicle_multiplier(car, 1).
vehicle_multiplier(bus, 1.5).
vehicle_multiplier(lorry, 2).
vehicle_multiplier(bike, 0.5).

% Violations - violation(Name, Base_Fine, Severity, Credit_Deduction)
violation(speeding, 3000, low, 2).
violation(red_light, 5000, medium, 4).
violation(drunk_driving, 25000, high, 10).
violation(no_helmet, 2000, low, 1).
     
%   Core Logic 

check_license(L_Num) :-
   repeat,
    write('Enter License Number (8 digits, e.g. 10234567.): '), 
    read(L_Num),
    (   valid_license(L_Num) ->
        write('License verified. Valid License in Sri Lanka.'), nl, !
    ; nl,
        write('Error: Incorrect License Number!'), nl,
        write('Invalid Input: '), write(L_Num), nl,
        write('(Must be a registered 8-digit number)'), nl, nl,
        write('Please try again.'), nl, nl,
        fail
    ).
% Credit and Validity check
check_status(Credits) :-
    Credits > 0,
    write('Status: License is VALID.'), nl,
    write('Remaining Credit Balance: '), write(Credits), write(' credits.'), nl.
check_status(_) :-
   write('Status: License is now INVALID (Credits are over)!'), nl.

%   Main Program 

start :-
    % Cleaning up previous session data
    retractall(current_vehicle(_)),
    retractall(current_type(_)),
    retractall(current_license(_)),
    retractall(driver_credits(_)),
    
    % Setting initial credits to 10
    assertz(driver_credits(10)),

    write('--- Traffic Violation Management System ---'), nl,
    
    % License input with unlimited retry
    check_license(L_Num),
    assertz(current_license(L_Num)),
    
    write('Enter Vehicle Number (e.g. wp_cab_1234.): '), read(V_Num),
    write('Enter Vehicle Type (bike, car, bus, lorry.): '), read(V_Type),
    
    assertz(current_vehicle(V_Num)),
    assertz(current_type(V_Type)),
    
    show_violations.

show_violations :-
    nl, write('--- Available Violations List ---'), nl,
    write('- speeding'), nl,
    write('- red_light'), nl,
    write('- drunk_driving'), nl,
    write('- no_helmet'), nl,
    
      write('Enter the Violation Name : '), read(Offense),
    generate_report(Offense).

% checking no_helmet violation (its only for bike)
generate_report(no_helmet) :-
    current_type(V_Type),
    V_Type \== bike, 
    write('Error: "no_helmet" violation is Only for bikes!'), nl,
     show_violations. % (Recursion)

generate_report(Offense) :-
    (violation(Offense, BaseFine, Severity, Penalty) ->
        current_type(V_Type),
        vehicle_multiplier(V_Type, Multiplier),
        
        % Calculate total fine based on vehicle type
        TotalFine is BaseFine * Multiplier,
        
        % Credit deduction 
        driver_credits(Current),
        NewBalance is Current - Penalty,
        retract(driver_credits(Current)),
        assertz(driver_credits(NewBalance)),
        
        % Final Report Output
        nl, write('======= TRAFFIC VIOLATION REPORT ======='), nl,
        write('License No     : '), current_license(L), write(L), nl,
        write('Vehicle No     : '), current_vehicle(V), write(V), nl,
        write('Vehicle Type   : '), write(V_Type), nl,
        write('Violation      : '), write(Offense), nl,
        write('Severity       : '), write(Severity), nl,
        write('Calculated Fine: Rs. '), write(TotalFine), nl,
        write('Credit Deducted: '), write(Penalty), nl,
        check_status(NewBalance),
        write('========================================'), nl
      ;
        write('Invalid violation name. Please re-enter.'), nl, 
          show_violations
    ).
