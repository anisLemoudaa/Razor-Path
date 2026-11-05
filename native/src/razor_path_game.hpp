        if (screen == RazorScreen::PLAYING) {
            if (code == Key::KEY_SPACE || code == Key::KEY_UP || code == Key::KEY_W) {
                jump_requested = true;
                jump_buffer_time = 0.16;
            }
            if (code == Key::KEY_J || code == Key::KEY_X) {
                attack_requested = true;
            }
        }
    }
    update_touch_state(event);
}

void RazorPathGame::_process(double delta) {
    animation_time += delta;
    background_time += delta;
    attack_time = std::max(0.0, attack_time - delta);
    attack_cooldown = std::max(0.0, attack_cooldown - delta);
    landing_time = std::max(0.0, landing_time - delta);
    toast_time = std::max(0.0, toast_time - delta);
    jump_buffer_time = std::max(0.0, jump_buffer_time - delta);
    coyote_time = on_ground ? 0.12 : std::max(0.0, coyote_time - delta);
    if (toast_time <= 0.0 && toast_label != nullptr) {
        toast_label->set_text(String());
    }
    for (Particle &particle : particles) {
        particle.position += particle.velocity * delta;
        particle.velocity.y += 460.0 * delta;
        particle.lifetime -= delta;
    }
    particles.erase(std::remove_if(particles.begin(), particles.end(), [](const Particle &p) { return p.lifetime <= 0.0; }), particles.end());
    if (screen == RazorScreen::PLAYING && hud_label != nullptr) {
        update_hud();
    }
    queue_redraw();
}

void RazorPathGame::_physics_process(double delta) {
    if (screen != RazorScreen::PLAYING) {
        return;
    }
    remaining_time = std::max(0.0, remaining_time - delta);
    if (remaining_time <= 0.0) {
        fail_run();
        return;
    }

    Input *input = Input::get_singleton();
    bool left = input->is_key_pressed(Key::KEY_A) || input->is_key_pressed(Key::KEY_LEFT);
    bool right = input->is_key_pressed(Key::KEY_D) || input->is_key_pressed(Key::KEY_RIGHT);
    bool attack = attack_requested || input->is_key_pressed(Key::KEY_J) || input->is_key_pressed(Key::KEY_X);
    for (const auto &entry : touch_actions) {
        left = left || entry.second == TouchAction::LEFT;
        right = right || entry.second == TouchAction::RIGHT;
    }

    const double axis = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    const double move_speed = 420.0;
    player_x = std::clamp(player_x + axis * move_speed * delta, 18.0, stage.world_width - 18.0);

    if (jump_requested || jump_buffer_time > 0.0) {
        jump_buffer_time = std::max(jump_buffer_time, 0.16);
    }
    if (jump_buffer_time > 0.0 && (on_ground || coyote_time > 0.0)) {
        player_vy = -780.0;
        on_ground = false;
        coyote_time = 0.0;
        jump_buffer_time = 0.0;
        total_jumps += 1;
        spawn_particles(Vector2(player_x, player_feet - 4.0), stage.monochrome ? rgba8(0x111111) : rgba8(0x685e49), 8, 95.0);
    }
    if (attack && attack_cooldown <= 0.0) {
        attack_time = 0.28;
        attack_cooldown = 0.36;
        const double dir = axis < 0.0 ? -1.0 : 1.0;
        const Rect2 strike(Vector2(player_x + dir * 18.0 - 24.0, player_feet - 112.0), Vector2(68.0, 82.0));
        for (Rect2 &hazard : stage.hazards) {
            if (strike.intersects(hazard)) {
                const Vector2 hazard_center = hazard.position + hazard.size * 0.5;
                hazard.position.x = -100000.0;
                spawn_particles(hazard_center, stage.monochrome ? rgba8(0x222222) : rgba8(0xe7b84b), 12, 130.0);
            }
        }
    }
    jump_requested = false;
    attack_requested = false;

    const double old_feet = player_feet;
    player_vy += 1950.0 * delta;
    player_feet += player_vy * delta;
    on_ground = false;
    for (const Rect2 &platform : stage.platforms) {
        const bool overlaps_x = player_x + 20.0 > platform.position.x && player_x - 20.0 < platform.position.x + platform.size.x;
        const bool crossed_top = old_feet <= platform.position.y + 4.0 && player_feet >= platform.position.y;
        if (overlaps_x && crossed_top && player_vy >= 0.0) {
            player_feet = platform.position.y;
            player_vy = 0.0;
            on_ground = true;
            coyote_time = 0.12;
        }
    }
    if (on_ground && old_feet > player_feet + 2.0) {
        landing_time = 0.12;
        spawn_particles(Vector2(player_x, player_feet - 2.0), stage.monochrome ? rgba8(0x444444) : rgba8(0x625c4f), 5, 55.0);
    }

    const Rect2 body = player_body_rect();
    for (const Rect2 &hazard : stage.hazards) {
        if (hazard.position.x > -500.0 && body.intersects(hazard)) {
            remaining_time = std::max(0.0, remaining_time - 10.0);
            player_x = stage.spawn.x;
            player_feet = stage.spawn.y;
            player_vy = 0.0;
            camera_x = 0.0;
            spawn_particles(Vector2(player_x, player_feet - 30.0), stage.monochrome ? rgba8(0x555555) : rgba8(0x744b42), 14, 100.0);
            break;
        }
    }
    for (size_t i = 0; i < stage.coins.size() && i < 256; ++i) {
        if (!stage_coin_collected[i] && body.grow(7.0).has_point(stage.coins[i])) {
            stage_coin_collected[i] = true;
            ++stage_coins;
            ++coins;
            spawn_particles(stage.coins[i], stage.monochrome ? rgba8(0x222222) : rgba8(0xd5a749), 12, 105.0);
            save_progress();
        }
    }

    if (player_feet > 900.0) {
        remaining_time = std::max(0.0, remaining_time - 10.0);
        player_x = stage.spawn.x;
        player_feet = stage.spawn.y;
        player_vy = 0.0;
        camera_x = 0.0;
    }
    if (std::abs(player_x - stage.exit.x) < 38.0 && std::abs(player_feet - stage.exit.y) < 90.0) {
        if (stage_coins >= static_cast<int32_t>(stage.required_coins)) {
            complete_stage();
            return;
        }
        if (toast_time <= 0.0) {
            toast_time = 1.8;
            if (toast_label != nullptr) {
                toast_label->set_text(ui("اجمع عملات أكثر لفتح المخرج"));
            }
        }
    }

    const double view_width = logical_size().x;
    const double max_camera = std::max(0.0, stage.world_width - view_width);
    const double target_camera = std::clamp(player_x - view_width * 0.38, 0.0, max_camera);
    camera_x += (target_camera - camera_x) * std::min(1.0, 8.0 * delta);
}
