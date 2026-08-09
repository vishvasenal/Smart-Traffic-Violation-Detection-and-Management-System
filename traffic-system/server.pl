%% ============================================================
%%  Traffic Violation Management System — HTTP Backend
%%  Wraps the original console logic (main 2.0.pl) as a JSON API
%%  and serves the web frontend from ./www
%% ============================================================

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).
:- use_module(library(http/json)).

%% ---------------- Dynamic session state ----------------
:- dynamic current_vehicle/1.
:- dynamic current_type/1.
:- dynamic current_license/1.
:- dynamic driver_credits/1.

%% ---------------- Original Facts (unchanged) ----------------

% Pre stored 5 license numbers (8 digits)
valid_license(10000000).
valid_license(10000001).
valid_license(10000002).
valid_license(10000003).
valid_license(10000004).

% Vehicle Multipliers
vehicle_multiplier(bike, 0.5).
vehicle_multiplier(light, 1).
vehicle_multiplier(heavy, 2).

% Violations
violation(speeding,      3000, low,    2).
violation(red_light,     5000, medium, 4).
violation(drunk_driving, 25000, high, 10).
violation(no_helmet,     2000, low,    1).

%% ============================================================
%%  HTTP routes
%% ============================================================

% Resolve ./www relative to THIS file, so the server works no matter
% which directory it's launched from.
:- prolog_load_context(directory, Dir),
   atomic_list_concat([Dir, '/www'], WWWPath),
   asserta(user:file_search_path(www, WWWPath)).

:- http_handler(root(.), http_reply_from_files(www(.), []), [prefix]).

:- http_handler('/api/start',     handle_start,     [methods([post])]).
:- http_handler('/api/license',   handle_license,    [methods([post])]).
:- http_handler('/api/vehicle',   handle_vehicle,    [methods([post])]).
:- http_handler('/api/violation', handle_violation,  [methods([post])]).
:- http_handler('/api/status',    handle_status,     [methods([get])]).

%% ---------------- /api/start ----------------
% Resets the session exactly like start/0 did before the input loop began.
handle_start(_Request) :-
    retractall(current_vehicle(_)),
    retractall(current_type(_)),
    retractall(current_license(_)),
    retractall(driver_credits(_)),
    assertz(driver_credits(10)),
    reply_json_dict(_{ ok: true, message: "New session started.", credits: 10 }).

%% ---------------- /api/license ----------------
% Body: {"license": 10000000}
% Mirrors check_license/1's valid/invalid branches (minus the repeat/fail loop,
% which the frontend now drives by re-submitting on error).
handle_license(Request) :-
    http_read_json_dict(Request, Data),
    get_dict(license, Data, RawLicense),
    normalize_license(RawLicense, License),
    ( integer(License), valid_license(License) ->
        retractall(current_license(_)),
        assertz(current_license(License)),
        reply_json_dict(_{
            valid: true,
            message: "License verified. Valid License in Sri Lanka."
        })
    ;
        reply_json_dict(_{
            valid: false,
            message: "Incorrect License Number! Must be a registered 8-digit number."
        })
    ).

normalize_license(L, L) :- integer(L), !.
normalize_license(L, N) :- (string(L) ; atom(L)), catch(number_string(N, L), _, fail), !.
normalize_license(_, invalid).

%% ---------------- /api/vehicle ----------------
% Body: {"vehicle_num": "wp_cab_1234", "vehicle_type": "bike"}
% Mirrors the vehicle-number read plus input_vehicle_type/0's validation loop.
handle_vehicle(Request) :-
    http_read_json_dict(Request, Data),
    get_dict(vehicle_num, Data, VNumRaw),
    get_dict(vehicle_type, Data, VTypeRaw),
    atom_string(VType, VTypeRaw),
    ( vehicle_multiplier(VType, _) ->
        retractall(current_vehicle(_)),
        retractall(current_type(_)),
        assertz(current_vehicle(VNumRaw)),
        assertz(current_type(VType)),
        reply_json_dict(_{
            valid: true,
            message: "Vehicle registered."
        })
    ;
        reply_json_dict(_{
            valid: false,
            message: "Invalid Vehicle Type! Please use bike, light, or heavy."
        })
    ).

%% ---------------- /api/violation ----------------
% Body: {"offense": "speeding"}
% Mirrors generate_report/1, including the no_helmet-only-for-bikes rule,
% but returns a JSON report instead of writing to the console.
handle_violation(Request) :-
    http_read_json_dict(Request, Data),
    get_dict(offense, Data, OffenseRaw),
    atom_string(Offense, OffenseRaw),
    ( \+ current_license(_) ->
        reply_json_dict(_{ success: false, message: "No active license. Please start over." })
    ; \+ current_type(_) ->
        reply_json_dict(_{ success: false, message: "Please register a vehicle first." })
    ; current_type(VType0), Offense == no_helmet, VType0 \== bike ->
        reply_json_dict(_{ success: false, message: "\"no_helmet\" violation is only for bikes!" })
    ; violation(Offense, BaseFine, Severity, Penalty) ->
        current_type(VType),
        vehicle_multiplier(VType, Multiplier),
        TotalFine is BaseFine * Multiplier,
        driver_credits(Current),
        NewBalance is Current - Penalty,
        retractall(driver_credits(_)),
        assertz(driver_credits(NewBalance)),
        current_license(L),
        current_vehicle(V),
        status_of(NewBalance, Status, StatusMessage),
        reply_json_dict(_{
            success: true,
            license: L,
            vehicle: V,
            vehicle_type: VType,
            offense: Offense,
            severity: Severity,
            base_fine: BaseFine,
            multiplier: Multiplier,
            fine: TotalFine,
            penalty: Penalty,
            new_balance: NewBalance,
            status: Status,
            status_message: StatusMessage
        })
    ;
        reply_json_dict(_{ success: false, message: "Invalid violation name. Please re-enter." })
    ).

status_of(Credits, "VALID", "License is VALID.") :- Credits > 0, !.
status_of(_, "INVALID", "License is now INVALID (Credits are over)!").

%% ---------------- /api/status ----------------
handle_status(_Request) :-
    ( driver_credits(Credits) -> true ; Credits = 10 ),
    status_of(Credits, Status, StatusMessage),
    ( current_license(L) -> License = L ; License = null ),
    ( current_vehicle(V) -> Vehicle = V ; Vehicle = null ),
    ( current_type(T) -> Type = T ; Type = null ),
    reply_json_dict(_{
        credits: Credits,
        status: Status,
        status_message: StatusMessage,
        license: License,
        vehicle: Vehicle,
        vehicle_type: Type
    }).

%% ============================================================
%%  Server startup
%% ============================================================

server(Port) :-
    assertz(driver_credits(10)),
    http_server(http_dispatch, [port(Port)]),
    format("~n=== Traffic Violation Management System ===~n"),
    format("Server running at http://localhost:~w~n~n", [Port]).

:- initialization(main).

main :-
    server(8080).
