    stage_index = requested_index;
    player_x = stage.spawn.x;
    player_feet = stage.spawn.y;
    player_vy = 0.0;
    camera_x = 0.0;
    stage_coins = 0;
    remaining_time = 180.0;
    on_ground = false;
    run_finalized = false;
    jump_requested = false;
    attack_requested = false;
    landing_time = 0.0;
    coyote_time = 0.0;
    jump_buffer_time = 0.0;
    std::fill(std::begin(stage_coin_collected), std::end(stage_coin_collected), false);
    return true;
}

void RazorPathGame::start_new_run() {
    total_jumps = 0;
    start_stage(1);
}
