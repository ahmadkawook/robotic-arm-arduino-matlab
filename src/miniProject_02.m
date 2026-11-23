%% Arduino-Based Robotic Arm Control Using MATLAB
% 4-DOF robotic arm (base, left, right, claw) driven by four SG90 servos.
% A joystick provides X/Y analog input; its push button cycles which
% servo the Y-axis controls. The X-axis always rotates the base.
%
% Hardware: Arduino Uno, 4x SG90 servos, joystick module, 3D-printed arm
% Requires: MATLAB Support Package for Arduino Hardware
%
% Pin map:
%   Base servo  -> D11      Joystick VRx -> A0
%   Left servo  -> D10      Joystick VRy -> A1
%   Right servo -> D9       Joystick SW  -> D3 (internal pull-up)
%   Claw servo  -> D6

%% Initial setup
if ~exist('a', 'var') || ~isvalid(a)
    a = arduino();
end

% Set up the servos
pins = {'D11', 'D10', 'D9', 'D6'};
servos = cell(1,4);
if ~exist('baseServo', 'var') || ~isvalid(baseServo), baseServo = servo(a, 'D11'); end
if ~exist('leftServo', 'var') || ~isvalid(leftServo), leftServo = servo(a, 'D10'); end
if ~exist('rightServo', 'var') || ~isvalid(rightServo), rightServo = servo(a, 'D9'); end
if ~exist('clawServo', 'var') || ~isvalid(clawServo), clawServo = servo(a, 'D6'); end

% Joystick button
configurePin(a, 'D3', 'Pullup');

% Default positions (0 to 1 = 0 to 180 degrees)
basePos  = 0.5;
leftPos  = 0.5;
rightPos = 0.5;
clawPos  = 0.5;

% Control variables
state = 1;          % 1 = Left, 2 = Right, 3 = Claw
sensitivity = 0.1;  % movement speed
deadzone = 0.2;     % joystick dead zone

fprintf('Arm active\n');

fprintf('Calibrating... DO NOT TOUCH JOYSTICK\n');
pause(1);
xCenter = readVoltage(a, 'A0');
yCenter = readVoltage(a, 'A1');
fprintf('Calibration complete. Center: X=%.2f, Y=%.2f\n', xCenter, yCenter);

%% Main control loop
while true

    % Read inputs
    vx = readVoltage(a, 'A0');
    vy = readVoltage(a, 'A1');
    btn = readDigitalPin(a, 'D3');

    % Button press (active low): cycle the controlled servo
    if btn == 0
        state = state + 1;
        if state > 3, state = 1; end

        % Print feedback so the operator knows which joint is active
        if state == 1, fprintf('Now controlling: LEFT SERVO\n');
        elseif state == 2, fprintf('Now controlling: RIGHT SERVO\n');
        elseif state == 3, fprintf('Now controlling: CLAW SERVO\n');
        end

        % Debounce: wait for the button to be released
        pause(0.2);
        while readDigitalPin(a, 'D3') == 0
            pause(0.01);
        end
    end

    % X-axis -> base rotation
    dx = (vx - 2.5) / 5;
    if abs(dx) > 0.05
        basePos = basePos + (dx * sensitivity);
    end

    % Y-axis -> currently selected servo
    dy = (vy - 2.5) / 5;
    if abs(dy) > 0.05
        if state == 1
            leftPos = leftPos + (dy * sensitivity);
        elseif state == 2
            rightPos = rightPos + (dy * sensitivity);
        elseif state == 3
            clawPos = clawPos + (dy * sensitivity);
        end
    end

    % Clamp positions to valid ranges
    basePos  = max(0, min(0.25, basePos));
    leftPos  = max(0, min(1, leftPos));
    rightPos = max(0, min(1, rightPos));
    clawPos  = max(0, min(1, clawPos));

    % Base range is limited to avoid a mechanical interference in the build
    basePos = max(0, min(0.25, basePos));

    writePosition(baseServo, basePos);
    writePosition(leftServo, leftPos);
    writePosition(rightServo, rightPos);
    writePosition(clawServo, clawPos);

    drawnow;
    pause(0.01);
end
