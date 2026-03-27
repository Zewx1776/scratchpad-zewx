local spell_data = {
    -- active spells
    blood_wave = {
        spell_id = 658216,
        buff_ids = {
            damage_reduction = 645480941,
        }
    },
    blood_mist = {
        spell_id = 493422,
        buff_ids = {
            base = 945423608,
            crit = 3919095796
        }
    },
    corpse_explosion = {
        spell_id = 432897,
        debuff_id = 2654502398
    },
    corpse_tendrils = {
        spell_id = 463349,
        debuff_id = 4263050
    },
    blight = {
        spell_id = 481293,
        debuff_id = 4055768098
    },
    bone_spear = {
        spell_id = 432879,
    },
    bone_splinters = {
        spell_id = 500962,
        buff_id = 1571808791,
    },
    decrepify = {
        spell_id = 915150,
        debuff_id = 955804540
    },
    hemorrhage = {
        spell_id = 484661,
        buff_id = 3673297682,
    },
    reap = {
        spell_id = 432896,
        buff_id = 4276614347
    },
    decompose = {
        spell_id = 463175,
        buff_id = 4276614347
    },
    blood_lance = {
        spell_id = 501629,
        buff_ids = {
            base = 2049179886,
            op_counter = 434533130,
            paranormal = 4223973841
        }
    },
    blood_surge = {
        spell_id = 592163,
        buff_ids = {
            op_counter = 434533130,
        }
    },
    sever = {
        spell_id = 481785,
        buff_ids = {
            vuln_counter = 3021530521,
        }
    },
    bone_prison = {
        spell_id = 493453,
        buff_ids = {
            base = 3238461883,
        },
        debuff_ids = {
            base = 229784669,
            vulnerable = 1126954416
        }
    },
    iron_maiden = {
        spell_id = 915152,
        debuff_id = 978737191
    },
    bone_spirit = {
        spell_id = 469641,
        buff_id = 1889746253
    },
    army_of_the_dead = {
        spell_id = 497193,
        buff_id = 2631161590
    },
    bone_storm = {
        spell_id = 499281,
        buff_id = 2263206809
    },
    soulrift = {
        spell_id = 1644584,
        buff_id = 183120667
    },
    raise_skeleton = {
        spell_id = 1059157,
    },
    golem_control = {
        spell_id = 440463,
    },

    evade = {
        spell_id = 337031, -- NOTE: Dont use, this is just here for the equipped spells lookup
        default = {
            spell_id = 337031,
            distance = 4,
            distance_sqr = 16,
        },
        metamorphosis = {
            spell_id = 1528413,
            distance = 6,
            distance_sqr = 36,
        },
    },

    -- aspects
    metamorphosis = {
        spell_id = 1865130,
        buff_id = 3807940699,
    },

    -- passives
    is_mounted = { -- NOTE: only determines if we are mounted
        spell_id = 1924,
        buff_id = 4294967295
    },
    rathmas_vigor = {
        spell_id = 495570,
        stack_counter = 622703449
    },

    -- paragon
    flesh_eater = {
        spell_id = 682016,
        buff_id = 3918042290,
        stack_counter = 1117121044
    },

    -- enemies
    enemies = {
        damage_resistance = {
            spell_id = 1094180,
            buff_ids = {
                provider = 2771801864,
                receiver = 2182649012
            }
        }
    },
}

return spell_data
