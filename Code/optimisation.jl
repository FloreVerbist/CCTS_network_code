function initiate_optimal_coordination_model(model, Social_decision, Tariff, Intercept, Initialization)
    # include("./parameters.jl") 
    # model = Model(optimizer_with_attributes(Gurobi.Optimizer, "DualReductions" => 0)) 
    model.ext[:variables] = Dict()
    model.ext[:expressions] = Dict()
    model.ext[:constraints] = Dict()
    model.ext[:parameters] = Dict()


    # predefining dictionaries to attach variables

    # f(x) = 0.390*(x)^(0.3426)
    # s1 = [0, 8, 300]
    # fd = f.(s1)

    # model = Model(optimizer_with_attributes(Gurobi.Optimizer, "DualReductions" => 0)) 
    
    # Binary (discrete) variables 
    delta  = model.ext[:variables][:delta ] = JuMP.@variable(model, delta[PIECES, PIPES], Bin)
    beta_off  = model.ext[:variables][:beta_off] = JuMP.@variable(model, beta_off[STORAGES_OFF], Bin)
    beta_inl  = model.ext[:variables][:beta_inl] = JuMP.@variable(model, beta_inl[STORAGES_INL], Bin)



    #delta_pos = model.ext[:variables][:delta_pos] = JuMP.@variable(model, delta_pos[PIECES, PIPES], Bin)
    #delta_neg = model.ext[:variables][:delta_neg] = JuMP.@variable(model, delta_neg[PIECES, PIPES], Bin)

    # Continuous variables 
    q_pipe_pos  = model.ext[:variables][:q_pipe_pos ] = JuMP.@variable(model, q_pipe_pos[PIECES, PIPES] >= 0)
    q_pipe_neg  = model.ext[:variables][:q_pipe_neg ] = JuMP.@variable(model, q_pipe_neg[PIECES, PIPES] >=0)
    q_pipe_tot  = model.ext[:variables][:q_pipe_tot ] = JuMP.@variable(model, q_pipe_tot[PIECES, PIPES] >= 0)
    q_inj_off = model.ext[:variables][:q_inj_off] =    JuMP.@variable(model, q_inj_off[STORAGES_OFF] >= 0)
    q_inj_inl = model.ext[:variables][:q_inj_inl] =     JuMP.@variable(model, q_inj_inl[STORAGES_INL] >= 0)
    TOT_capture_cluster = model.ext[:variables][:TOT_capture_cluster] =     JuMP.@variable(model, TOT_capture_cluster[CLUSTERS] >= 0)
    # Scaling_ccts = 2.0              # indicates how many times T&S, CC is more expensive in relation to the initial data 

    c_operator = model.ext[:variables][:c_operator] =     JuMP.@variable(model, c_operator >= 0)
    c_transport = model.ext[:variables][:c_transport] =     JuMP.@variable(model, c_transport >= 0)
    c_booster_pump = model.ext[:variables][:c_booster_pump] =     JuMP.@variable(model, c_booster_pump >= 0)
    c_storage = model.ext[:variables][:c_storage] =     JuMP.@variable(model, c_storage >= 0)
    # pipe_multiple = model.ext[:variables][:pipe_multiple] =     JuMP.@variable(model, pipe_multiple[PIECES, PIPES] >= 1)
    # constraints 
    cc_emitter = model.ext[:variables][:cc_emitter] =     JuMP.@variable(model, cc_emitter[EMITTERS] >= 0, start = 1)

    if Initialization .== true 
        # binaries_hot_start = CSV.read("./Input data files/CSV hot start $(detail_level)/$(Region)_$(Scenario_name)_$(Pieces).csv", DataFrame)

        # for i in PIECES
        #     set_start_value.(delta[i, PIPES], binaries_hot_start[!, Symbol.(i)])
        # end
        # set_start_value.(beta_off, binaries_hot_start[!,"Storage_off"][1:length(STORAGES_OFF)])
        # set_start_value.(beta_inl, binaries_hot_start[!,"Storage_inl"][1:length(STORAGES_INL)])
        filename_all_variables ="./Input data files/CSV hot start $(detail_level)/Dict_$(Region)_$(Scenario_name)_$(Pieces).csv"

        Prestart_df = CSV.read(filename_all_variables, DataFrame)


        x2 =  all_variables(model);
        for (n, v) in zip(Prestart_df[!, "first"], Prestart_df[!, "second"])
            x2_index = findfirst(n2 -> string(n2) == n, x2)
            try
            set_start_value(x2[x2_index], v)
            catch e
                missing
            end
        end
        
    else 
        skip
    end 


    # Constraint 2: participating emitters to CO2 chain
    if Social_decision == true # Social optimum scenario
        @constraint(model, [n=EMITTERS],  cc_emitter[n] <= 1) # more flexibility here. 
        # for e in EMITTERS 
        #     if TOT_capture_1_CO2[e] == 0.0
        #         fix.(cc_emitter[e],0; force=true)
        #     else 
        #     end
        # end
        #@constraint(model, [n=[i for i in EMITTERS if TOT_capture_1_CO2[i] == 0.0]],  cc_emitter[n] .== 0)
    else  # Max participation scenario
        # cc_emitter = model.ext[:variables][:cc_emitter] =     JuMP.@variable(model, cc_emitter[EMITTERS] >= 0)
        # @constraint(model, [n=EMITTERS],  cc_emitter[n] <= 1) 
        for e in EMITTERS 
            if TOT_capture_1_CO2[e] == 0.0
                fix.(cc_emitter[e],0; force=true)
            else 
                fix.(cc_emitter[e],1; force=true)
            end
        end

        # @constraint(model, [n=[i for i in EMITTERS if TOT_capture_1_CO2[i] > 0.0]],  cc_emitter[n] .== 1)
        # @constraint(model, [n=[i for i in EMITTERS if TOT_capture_1_CO2[i] == 0.0]],  cc_emitter[n] .== 0)
    end

    if Tariff == true 
        @constraint(model,  [n=EMITTERS],  cc_emitter[n].*(CAPEX_1[n] .+ OPEX_1[n] + tariff*TOT_capture_1_CO2[n]) <= (CAPEX_noCC[n] .+ OPEX_noCC[n])) 
        # @constraint(model, sum(cc_emitter[e]*(TOT_bio_CO2[e]+TOT_fossil_CO2[e]).*tariff for e in EMITTERS) >= c_operator  )
    else
        skip 
    end


    # # Constraint 4: constraint to make sure that delta is equal to 1 when q_pipe's is positive. 
    # upper bounds
    if Intercept == false
        @constraint(model, [pc=PIECES, p=PIPES],  delta[pc,p] .== 0)
        @constraint(model, [pc=PIECES, p=PIPES], 
        q_pipe_tot[pc, p]  <= Mpipe_pc_transport[pc+1])
    else 
        @constraint(model, [pc=PIECES, p=PIPES], 
        q_pipe_tot[pc, p]  <= delta[pc, p]*Mpipe_pc_transport[pc+1])
    end

    # lower bounds
    if Pieces > 1 
        @constraint(model, [pc=PIECES, p=PIPES], 
            delta[pc, p]*Mpipe_pc_transport[pc]  <= q_pipe_tot[pc, p])
        @constraint(model, [p=PIPES], 
            sum(delta[pc, p] for pc in PIECES) <= 1)
    else
        skip
    end
    
    # it seems that none of these are actually necessary. 
        # @constraint(model, [pc=PIECES, p=PIPES], 
        # delta_pos[pc, p]*q_pipe_pos[pc, p]  <= delta[pc, p]*Mpipe_pc_transport[pc+1])
        # @constraint(model, [pc=PIECES, p=PIPES], 
        # (1-delta_pos[pc, p])*q_pipe_neg[pc, p]  <= delta[pc, p]*Mpipe_pc_transport[pc+1])
        # @constraint(model, [pc=PIECES, p=PIPES], 
        # (1-delta_neg[pc, p])*q_pipe_pos[pc, p]  <= delta[pc, p]*Mpipe_pc_transport[pc+1])
        # @constraint(model, [pc=PIECES, p=PIPES], 
        # delta_neg[pc, p]*q_pipe_neg[pc, p]  <= delta[pc, p]*Mpipe_pc_transport[pc+1])
        # @constraint(model, [pc=PIECES, p=PIPES], 
        # delta_neg[pc, p] + delta_pos[pc, p] <= 1.0)

    # expression on total transport in one pipeline
    @constraint(model,  [pc=PIECES, p=PIPES], q_pipe_tot[pc, p] .== q_pipe_pos[pc, p] + q_pipe_neg[pc, p])
   
    # expression on captured amounts per cluster
    @constraint(model, [c=CLUSTERS], TOT_capture_cluster[c] .== sum(cc_emitter[e]*(TOT_bio_CO2[e]+TOT_fossil_CO2[e])  for e in EMITTERS if Emitter_cluster[e].==c) )
   
    # Constraint 1: flow constraint at each node i (storage, terminal, routing, emitter): this constraint also determines which direction will be positive, and which negative
    # @constraint(model,  [i=NODES], 
    # sum((q_pipe_pos[pc, (n1,n)]- q_pipe_neg[pc, (n1,n)]) for (n1,n) in PIPES, pc in PIECES if n==i)   + sum(cc_emitter[n]*(TOT_bio_CO2[n]+TOT_fossil_CO2[n]) for n in EMITTERS if Emitter_cluster[n]==i) -  sum((q_pipe_pos[pc, (n,n1)]- q_pipe_neg[pc, (n,n1)]) for (n,n1) in PIPES, pc in PIECES if n==i) - sum(q_inj_off[n] for n in STORAGES_OFF if n==i)  - sum(q_inj_inl[n] for n in STORAGES_INL if n==i)== 0)
    @constraint(model,  [i=NODES], 
    sum((q_pipe_pos[pc, (n1,n)]- q_pipe_neg[pc, (n1,n)]) for (n1,n) in PIPES, pc in PIECES if n==i)   + sum(TOT_capture_cluster[c] for c in CLUSTERS if c==i) -  sum((q_pipe_pos[pc, (n,n1)]- q_pipe_neg[pc, (n,n1)]) for (n,n1) in PIPES, pc in PIECES if n==i) - sum(q_inj_off[n] for n in STORAGES_OFF if n==i)  - sum(q_inj_inl[n] for n in STORAGES_INL if n==i)== 0)

    # Constraint 3: constraint to make sure that all transported CO2 ends up in a storage location: destination node l 
    # @constraint(model, 
    # sum( cc_emitter[n]*(TOT_bio_CO2[n]+TOT_fossil_CO2[n]) for n in EMITTERS) == sum((q_pipe_pos[pc, l] + q_pipe_neg[pc, l]) for l in SPIPES, pc in PIECES))
    # # NO Antwerp diest connection
    #  @constraint(model, q_pipe_pos[1, ("C20", "C18")] ==0.0)
    #  @constraint(model, q_pipe_neg[1, ("C20", "C18")] ==0.0)


    # The below constraint is needed
    @constraint(model, 
    sum( TOT_capture_cluster[c] for c in CLUSTERS) == sum(q_inj_off[n] for n in STORAGES_OFF) + sum(q_inj_inl[n] for n in STORAGES_INL))

    # # expression on max allowed storage: 
    # @constraint(model, sum( TOT_capture_cluster[c] for c in CLUSTERS)  .<= 15.0)


    
    # Constraint 5: Constraint to limit the yearly storage capacity at each offshore location 
    @constraint(model,  [i=STORAGES_OFF],  q_inj_off[i] <= beta_off[i]*Storage_off_capacity[i])

    # Constraint 6: Constraint to limit the yearly storage capacity at each offshore location 
    @constraint(model,  [i=STORAGES_INL],  q_inj_inl[i] <= beta_inl[i]*Storage_inl_capacity[i])


    # piecewise
    @constraint(model, c_transport .==  sum((A_0_pc_transport[pc]*delta[pc,p] + A_1_pc_transport[pc].*(q_pipe_tot[pc,p])).*Pipe_distance[p] for p in PIPES, pc in PIECES)) 

    @constraint(model, c_booster_pump .== sum(((1+ OandM_BP) *BP_inv*sum(delta[pc, p] for pc in PIECES) +  BP_elec_cons * P_elec /(3.6*10^3) *sum(q_pipe_tot[pc, p] for pc in PIECES))*Pipe_distance[p] for p in PIPES)) 

    #@constraint(model, c_storage .== sum((1+OandM_storage)*(C_reservoir_inv + C_drilling_inv + C_surface_facility_inv + C_monitoring_inl)*beta_inl[s] for s in STORAGES_INL) + sum((1+OandM_storage)*(C_reservoir_inv + C_drilling_inv + C_surface_facility_inv)*beta_off[s] + C_monitoring_off_per_ton*q_inj_off[s]  for s in STORAGES_OFF))
    @constraint(model, c_storage .== sum((1+OandM_storage)*(C_reservoir_inv + C_drilling_inv*q_inj_inl[s] + C_surface_facility_inv + C_monitoring_inl)*beta_inl[s] for s in STORAGES_INL) + sum((1+OandM_storage)*(C_reservoir_inv + C_drilling_inv*q_inj_off[s] + C_surface_facility_inv)*beta_off[s] + C_monitoring_off_per_ton*q_inj_off[s]  for s in STORAGES_OFF))

    @constraint(model, c_operator .==  # costs of operator in EURpa
    Scaling_ccts*(c_transport + c_booster_pump + c_storage))   

    # objective 

    # objective = model.ext[:objective] =  @objective(model, Min, # in MEURpa - MILP
    # # Capital and O&M cost of pipeline
    # c_operator
    # .+ #trade off with emitter
    # sum(cc_emitter[n].*(CAPEX_1[n] .+ OPEX_1[n]) + (1-cc_emitter[n]).*(CAPEX_noCC[n] .+ OPEX_noCC[n]) for n in EMITTERS)) # is more prone to MILP gap
   
   
    objective = model.ext[:objective] =  @objective(model, Min, # in MEURpa - MILP
    # Capital and O&M cost of pipeline
    c_operator
    .-  #trade off with emitter
    sum(cc_emitter[n].*(min((CAPEX_noCC[n] .+ OPEX_noCC[n]) .- (CAPEX_1[n] .+ OPEX_1[n]), (TOT_fossil_CO2[n])*CO2_tax)) for n in EMITTERS))



    return model

end

