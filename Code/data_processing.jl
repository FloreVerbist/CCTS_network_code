function PMT_calculator(CAPEX_tot, periods, interest)
    # PMT = periodic payment amount 
    cost_PMT = (CAPEX_tot.*interest.*(1+interest)^(periods))/((1+interest)^periods - 1)
    return cost_PMT
end 



function USD_2_EUR_calculator(cost, reference_year, USD_EUR_dict)
    cost_usd_2_eur = USD_EUR_dict[reference_year]*cost
    return cost_usd_2_eur
end

function DCCI_calculator(cost, original_year, reference_year, DCCI_dict)
    original_year_adj = original_year + 0.25
    cost_inflation = cost.* (DCCI_dict[reference_year]/DCCI_dict[original_year_adj])
    return cost_inflation  
end

function CCTS_element_selection(Region::String)
    if Region == "Trilateral"
        Pipeline_NUTS0 = ["BE", "NL", "DE", "FR", "LU", "NO", "SE", "DK"]
        #Pipeline_NUTS0 = ["BE", "NL", "DE", "FR"]
        NUTS_0 = ["BE" "NL"]   #  NUTS_0 = ["BE"] #
        if France == true 
            NUTS_2 = ["DEA" "FRE1" "FRE2"]  # ["DEA"] or  NUTS_2 = ["DEA" "FRE1" "FRE2"]  # PROBLEM: 2 dots are connected to south region, not to north... gives problem "DEA" NUTS_2 = []
        else 
            NUTS_2 = ["DEA"]
        end 
        SECTOR_id = [1 2 3 4 5 6]
        global EMITTERS, CLUSTERS = emitter_cluster_selection(Emitters, NUTS_0, NUTS_2, SECTOR_id)
        global Pipelines = Pipelines_all[in.(Pipelines_all[:, "NUTS0"], Ref(Pipeline_NUTS0)), :] # Pipelines = Pipelines_all
        global Routing_nodes = Routing_nodes_all[in.(Routing_nodes_all[:, "NUTS0"], Ref(Pipeline_NUTS0)), :] # Routing_nodes = Routing_nodes_all
    elseif Region == "Europe" 
        global Pipelines = Pipelines_all
        global Routing_nodes = Routing_nodes_all
        global EMITTERS = unique(Emitters[.!ismissing.(Emitters.Config_id_1), "Emitter_id"])
        Clusters_emitters = unique(Emitters[in.(Emitters[:,"Emitter_id"], Ref(EMITTERS)), "Cluster_julia"])
        global CLUSTERS = sort(Clusters_emitters, by = x -> parse(Int, replace(x, r"[^\d]" => "")))
    else
        print("Error: define Region as Europe or Trilateral")
    end 
return EMITTERS
end




function cost_converter(cost, PMT_periods, interest, original_year, reference_year, currency_conv::Bool)
    try 
        cost = PMT_calculator(cost, PMT_periods, interest)
    catch 
        skip 
    end
    try 
        cost = DCCI_calculator(cost, original_year, reference_year, DCCI_dict)
    catch 
        skip 
    end

    if currency_conv == true
        try 
            cost = USD_2_EUR_calculator(cost, reference_year, USD_EUR_dict)
        catch 
            skip 
        end
    else 
    end
    cost_converted = cost

    return cost_converted
end



function piecewise_error(Range_opt, Pieces, Samples, Intercept)
    column_names = vcat(["A_0", "A_1"], ["Total_error", "x_breakpoints", "y_breakpoints"])
    data = Dict(name => Any[] for name in column_names)
    Collect_df = DataFrame(data)
    x_range = range(Range_opt[1], Range_opt[2], length=Range_opt[2])  # High-resolution sampling
    y_values = f_transport.(x_range)
    Random.seed!(123)
    for s in 1:Samples
        breakpoints = vcat(Range_opt[1], sort(rand(Range_opt[1]:Range_opt[2], (Pieces-1))), Range_opt[2])
        # Ensure breakpoints are sorted

        # Split the domain into intervals based on breakpoints
        segments = [x_range[(x_range .>= breakpoints[i]) .& (x_range .< breakpoints[i+1])] for i in 1:(length(breakpoints)-1)]

        
        total_error = 0.0
        p_0 = []
        p_1 = []
        for (pc, seg) in enumerate(segments)
            if isempty(seg)
                continue
            end
            # Fit a linear model for this segment
            x_seg = seg
            y_seg = f_transport.(x_seg)

            
            # Compute least squares error for this segment
            if Intercept == false
                p_0_noI = 0.0
                p_1_noI = sum(x_seg .* y_seg) / sum(x_seg .* x_seg)  # Linear fit
                y_fit = p_1_noI .* x_seg .+ p_0_noI
                total_error += sum((y_seg .- y_fit).^2)
                push!(p_0, p_0_noI)
                push!(p_1, p_1_noI)
            else 
                p = fit(x_seg, y_seg,1)  # Linear fit
                y_fit = p[1] .* x_seg .+ p[0]
                total_error += sum((y_seg .- y_fit).^2)
                push!(p_0, p[0])
                push!(p_1, p[1])
            end

        end
        push!(Collect_df[!, "A_0"], p_0)
        push!(Collect_df[!, "A_1"], p_1)
        push!(Collect_df[!, "Total_error"], total_error)
        push!(Collect_df[!, "x_breakpoints"], breakpoints)
        push!(Collect_df[!, "y_breakpoints"], f_transport.(breakpoints))

    end


    Regression_transport = Collect_df[Collect_df[!,"Total_error"] .==minimum(Collect_df[!,"Total_error"]),:]
    return Regression_transport
end




function opt_result_extracting4visualisation(model)
    epsilon = 10^-4
    Pipe_set_opt = OrderedDict{Int,Any}()
    Pipe_size_opt = OrderedDict{Int,Float64}()

    
        # Values_p_neg = Dict(p => sum(value.(model[:q_pipe_neg][pc,p]) for pc in PIECES) for p in PIPES)
        # V_p_neg = [v for (k, v) in  Values_p_neg if v >= epsilon]
        # K_p_neg_origin = [k[1] for (k, v) in Values_p_neg if v >= epsilon]
        # K_p_neg_destination = [k[2] for (k, v) in Values_p_neg if v >= epsilon]
        # Values_p_pos = Dict(p => sum(value.(model[:q_pipe_pos][pc,p]) for pc in PIECES) for p in PIPES)
        # V_p_pos = [v for (k, v) in Values_p_pos if v >= epsilon]
        # K_p_pos_origin = [k[1] for (k, v) in Values_p_pos if v >= epsilon]
        # K_p_pos_destination = [k[2] for (k, v) in Values_p_pos if v >= epsilon]

        # V_p = vcat(V_p_neg, V_p_pos)
        # K_p_origin = vcat(K_p_neg_origin, K_p_pos_origin)
        # K_p_destination = vcat(K_p_neg_destination, K_p_pos_destination)

    Values_q = Dict(p => sum(value.(model[:q_pipe_tot][pc,p]) for pc in PIECES) for p in PIPES)
    V_p =  [v for (k, v) in Values_q if v >= epsilon]
    K_p_origin = [k[1] for (k, v) in Values_q if v >= epsilon]
    K_p_destination = [k[2] for (k, v) in Values_q if v >= epsilon]

    for i in 1:length(V_p)
        print(i)
        #try # verwijder
        Pipe_coor_opt = [float.(Nodes_all[Nodes_all[!,"Node_id"].== K_p_origin[i],"Lon"][1]) float.(Nodes_all[Nodes_all[!,"Node_id"].== K_p_origin[i],"Lat"][1]) ; float.(Nodes_all[Nodes_all[!,"Node_id"].== K_p_destination[i],"Lon"][1]) float.(Nodes_all[Nodes_all[!,"Node_id"].== K_p_destination[i],"Lat"][1])]
        Pipe_name_opt = [string.(Nodes_all[Nodes_all[!,"Node_id"].== K_p_origin[i],"Node_id"]); string.(Nodes_all[Nodes_all[!,"Node_id"].== K_p_destination[i],"Node_id"])]
        #Pipe_set_opt[i] = mat2ds(Pipe_coor_opt, Pipe_name_opt)
        Pipe_set_opt[i] = Pipe_coor_opt
        Pipe_size_opt[i] = V_p[i]
        # catch 
        # end
    end     
    
    Pipes_opt_co_na = values(Pipe_set_opt)
    Pipes_opt_sizes = values(Pipe_size_opt)
    


    return Pipes_opt_co_na, Pipes_opt_sizes #, Sline_opt_co_na, Sline_opt_sizes
end


function emitter_cluster_selection(Emitters, NUTS_0, NUTS_2, SECTOR_id)
    Emitters_filtered = Emitters[.!ismissing.(Emitters.Config_id_1), :]
    Emitters_sector_id = Emitters_filtered[in.(Emitters_filtered[:, "Sector_id"], Ref(SECTOR_id)), :]
    selected_emitters_NUTS_0 = Emitters_sector_id[in.(Emitters_sector_id[:, "NUTS0"], Ref(NUTS_0)), "Emitter_id"]
    selected_emitters_NUTS_2 = vcat([Emitters_sector_id[occursin.("$(i)", Emitters_sector_id[:, "NUTS3"]), "Emitter_id"] for i in NUTS_2]...)
    combinded_emitters = vcat(selected_emitters_NUTS_0, selected_emitters_NUTS_2)
    EMITTERS =unique(combinded_emitters)
    
    Clusters_emitters = unique(Emitters[in.(Emitters[:,"Emitter_id"], Ref(EMITTERS)), "Cluster_julia"])
    CLUSTERS = sort(Clusters_emitters, by = x -> parse(Int, replace(x, r"[^\d]" => "")))

    return EMITTERS, CLUSTERS 
end

function CMU_pipe_construction(PMT_periods, interest, reference_year, Plotting::Bool)


    # Other literature sources 
        # DEA total investment cost of a dense phase pipeline offshore in EUR/(tCO2/h)/m of 120 t CO2/h  = 26-43 
        # source: https://ens.dk/en/analyses-and-statistics/technology-data-carbon-capture-transport-and-storage
        h_yr = 24*365 # h/yr
        m_km = 1000  #m/km 
        f_annual = interest * (1 + interest)^PMT_periods / ((1 + interest)^PMT_periods -1)
       
        x_dea = [120, 120, 120, 120]  # tCO2/h
        y_dea = [10, 17, 26, 43]  # EUR/(tCO2/h)/m
        y_dea_OandM = [10, 30, 10, 30] #EUR/(tCO2/h)/yr/km

        x_dea_MtCO2_1 = x_dea .* h_yr ./ 10^6  # MtCO2/yr
        x_dea_MtCO2 = vcat(x_dea_MtCO2_1, 2.5)
        y_dea_total = y_dea .* x_dea .* m_km ./ 10^6 # MEUR/km 
        y_dea_specific = y_dea_total ./ x_dea_MtCO2_1

        y_dea_OandM_annualised = y_dea_OandM .* x_dea  / 10^6  #MEUR/(yr.km)
        y_dea_total_annualised_1 = (y_dea_total) .* f_annual .+ y_dea_OandM_annualised #MEUR/(yr.km)
        y_dea_total_annualised = vcat(y_dea_total_annualised_1, 6.7/180*2.5)
        y_dea_specific_annualised = y_dea_total_annualised ./  x_dea_MtCO2 # EUR/tCO2 
    # DEA 2 

    # JRC   
        x_JRC_MtCO2 = [10, 50, 95] # MtCO2/yr
        y_JRC_total = [1.3, 3.1, 5] # MEUR(2022)/km

        y_JRC_total_annualised = y_JRC_total * f_annual #MEUR/(yr.km)
        y_JRC_specific_annualised = y_JRC_total_annualised ./ x_JRC_MtCO2 # EUR/tCO2

    # IPCC  source: https://ens.dk/en/analyses-and-statistics/technology-data-carbon-capture-transport-and-storage (fig 65)
        x_ippc_MtCO2 =  [2.5, 2.5, 5, 5, 20, 20, 30, 30 ] # upper and lower ranges MtCO2/yr
        y_ippc_specific_usd = [4, 7, 2, 5, 1, 2, 0.8, 1.8]./250 # USdollar/tCO2 (for pipe of 250 km)
        y_ipcc_specific = cost_converter(y_ippc_specific_usd, "", interest, 2005, reference_year, true) # EUR/tCO2 (non annualised)
        y_ipcc_specific_annualised = y_ipcc_specific   # EUR/tCO2.km annualised - assuming this was already annualised data
        y_ipcc_total_annualised = y_ipcc_specific_annualised .*  x_ippc_MtCO2 # MEUR/yr.km

    # ZEP - https://zeroemissionsplatform.eu/publication/the-costs-of-co2-transport/
        x_zep_MtCO2 = [2.5, 2.5, 2.5, 2.5,  2.5, 20, 20, 20, 20, 20, 20, 20]
        y_zep_specific_annualised = [5.4, 9.3, 20.4, 28.7, 51.7, 1.5, 3.7, 5.3, 3.4, 6.0, 8.2, 16.3]./ [180, 180, 500, 770, 1500, 180, 500, 750, 180, 500, 750, 1500] #EUR/tCO2/km 
        y_zep_total_annualised = y_zep_specific_annualised .* x_zep_MtCO2


    # S Mccoy and E Rubin. “An engineering-economic model of pipeline transport of
    # CO2 with application to carbon capture and storage”. In: International Journal
    # of Greenhouse Gas Control 2.2 (Apr. 2008), pp. 219–229. issn: 17505836. doi:
    # 10.1016/S1750-5836(07)00119-3. url: https://linkinghub.elsevier.
    # com/retrieve/pii/S1750583607001193 (visited on 03/11/2024).


    # Original input data from E. Rubin et al. (2008): costs in US dollar 2004, diameters in inches and lenghts in km. C = a0*L^(a1)*D^(a2)
    # Materials: cost of line pipe, pipe coatings, and cathodic protection
    # Labor: pipeline construction labor
    # ROW: cost of obtaining right-of-way for the pipeline and allowance for damages to landowners’ property during construction
    # Miscellaneous: Miscellaneous includes the costs of surveying, engineering, supervision, contingencies, telecommunications equipment, freight, taxes, allowances for funds used during construction (AFUDC), administration and overheads, and regulatory filing fees. 
    Labels = ["Materials", "Labor", "ROW", "Miscellaneous"]
    a0_log = [3.112, 4.487, 3.950, 4.390]  # No region specific parameters added
    a0 = [10^(a0_log[i]) for i in 1:length(a0_log)] # a0_log = log(b) in paper and b = a0 here 
    # a1 = [0.901,0.820,1.049, 0.783]  # bivariate: function non-linearly dependend on length  
    a1 = [1.0,1.0, 1.0, 1.0] # univariate: function linearly dependend on length 
    a2 = [1.590,0.940, 0.403, 0.791] 

    original_year = 2004
    currency_converter = true
    A0_pipe_construct = cost_converter(a0, PMT_periods, interest, original_year, reference_year, currency_converter)./10^6 # MtEUR/yr 
    A0_pipe_construct_total = cost_converter(a0, "none", interest, original_year, reference_year, currency_converter)./10^6 # MtEUR/yr 
    A2_pipe_construct = a2 
    # IEA GHG. Building the Cost Curves for CO2 Storage: European Sector. Technical Report 2005/2, International Energy Agency, 2005. URL
    # https://ieaghg.org/publications/building-the-cost-curves-for-co2-storage-european-sector/.

   
    # Q_m = Pipes_opt_sizes .* 10^9 ./ (365*24*60*60) #kg/s 
    # Diameter = ((Q_MtperY.* 10^9 ./ (365*24*60*60))./(Velocity*pi*0.25*Density_2)).^0.5*Inch_per_meter  # m --> output slightly closer to Middelton, 2012
    x_max = 80
    Qm_vect = 0:2.5:x_max #Mton

    L =1   #km
    # f_transport(q) = (1+OandM_pipes).*sum(A0_pipe_construct.*(((q.* 10^9 ./ (365*24*60*60))./(Velocity*pi*0.25*Density_2)).^0.5*Inch_per_meter).^(A2_pipe_construct)) #MEUR

    D_max = mass_flow_to_diameter(x_max)
    if Plotting == true
        ################################################################
        # Annualised (per km)
        f_pipe_construct_annualised(x) = A0_pipe_construct.*(((x.* 10^9 ./ (365*24*60*60))./(Velocity*pi*0.25*Density_2)).^0.5*Inch_per_meter).^(A2_pipe_construct)*L # !!ADJUSTMENT HERE # univariate

        p =Plots.plot(size=(800, 500), xtickfont=font(15), ytickfont = font(15), legendfont = font(15), guidefont = font(15), legend =:bottomright)
        y_var = []
        for i in 1:length(a0)
            y_var_tot = []

            for j in 1:length(Qm_vect)
                y_var = push!(y_var, f_pipe_construct_annualised(Qm_vect[j])[i])
            end
            x_var = Qm_vect # Mt/yr

        end
        x_flat = Float64.(repeat(x_var,4))
        y_flat = Float64.(y_var) .* Scaling_ccts # !!ADJUSTMENT HERE
        Colors = ["springgreen4", "springgreen2", "lightseagreen", "darkseagreen1"]
        groupedbar!(x_flat, y_flat, group = repeat(Labels, inner = length(Qm_vect)), color = repeat(Colors, inner = length(Qm_vect)), xlabel = L"Mass flow MtCO$_2$/yr", ylabel = "MEUR/yr($(reference_year)) for $(L) km", bar_position = :stack)

        x_var = Qm_vect # Mt/yr

        # y_var = [sum(f_pipe_construct_annualised(Qm_vect[j])[i]  for i in 1:length(a0)) for j in 1:length(Qm_vect)] .* Scaling_ccts # !!ADJUSTMENT HERE
       
        LS = [:solid :dash]
       
        for p_nr in 1:2
            Regression_transport =  piecewise_error(Range_opt, p_nr, Samples, Intercept)
            # println("Transport Regression parameters:", Regression_transport)
            A_0_pc_transport = Regression_transport[!,"A_0"][1] * Scaling_ccts # !!ADJUSTMENT HERE
            A_1_pc_transport = Regression_transport[!,"A_1"][1] * Scaling_ccts # !!ADJUSTMENT HERE
            x_breakpoints = Regression_transport[!,"x_breakpoints"][1]
            y_value_linear = (A_0_pc_transport .+ A_1_pc_transport .* transpose(x_var)) ./ (1 + OandM_pipes)
            nrows = size(y_value_linear, 1)
            y_masked = fill(0.0, length(x_var))
            for i in 1:nrows
                idx = (x_var .<= x_breakpoints[i+1]) .&  (x_breakpoints[i] .<= x_var)
                y_masked[idx] = y_value_linear[i, idx]
            end
            # Plots.bar!(x_var, y_var*(1+OandM_pipes), label = "Total construction (annualised)", xlabel = "Mass flow MtCO2/yr", ylabel = "MEUR/yr($(reference_year)) for $(L) km", ls = :solid, color = "black", lw = 2)
            # Plots.bar!(x_var, y_var*OandM_pipes, label = "Total O&M", xlabel = "Mass flow MtCO2/yr", ylabel = "MEUR/yr($(reference_year)) for $(L) km", ls = :dash, color = "grey", lw = 2)
            Plots.plot!(x_var, y_masked, label = "$(p_nr)-piece linear regression", xlabel = "Mass flow MtCO2/yr", ylabel = "MEUR($(reference_year))/yr for $(L) km (annualised)", lw=2, color = "black", xlim = [0, x_max], linestyle=LS[p_nr])
        end

        Plots.plot!(twinx(p), xlabel = "", ylabel= "", yticks = false)
        # Plots.plot!(x_var, 2*(A_0_pc_transport .+ A_1_pc_transport.*x_var), color="black")
        Plots.scatter!(x_zep_MtCO2, y_zep_total_annualised, label= "ZEP", markershape= :x, color = "black", markersize=4)
        Plots.scatter!(x_ippc_MtCO2, y_ipcc_total_annualised, label= "IPCC", markershape= :^,color = "black", markersize=4)
        Plots.scatter!(x_JRC_MtCO2, y_JRC_total_annualised, label= "JRC", markershape= :v,color = "black", markersize=4)
        Plots.scatter!(x_dea_MtCO2, y_dea_total_annualised, label="DEA",  markershape= :o, color = "black", markersize=4, legend=:topright)

        Plots.plot!(twiny(p), xlabel = "Pipeline diameter [m]", ylabel= "", xlim = ([0, D_max]), xtickfont=font(15), ytickfont = font(15), legendfont = font(15), guidefont = font(15))
        Plots.plot!(twinx(p), xlabel = "", ylabel= "", yticks = false)
        # Plots.plot!([20, 20], [0, 1.5], label = false, ls=:dash, color = :black)
        



        
        display(p)
        save_path = "./Figures/Pipe_cost_yr_MEURpkm.svg"
        Plots.savefig(p, save_path)
        ################################################################
        # Levelised costs for certain length L en certain mass flow 
        f_pipe_construct_annualised(x) = A0_pipe_construct.*(((x.* 10^9 ./ (365*24*60*60))./(Velocity*pi*0.25*Density_2)).^0.5*Inch_per_meter).^(A2_pipe_construct)*L # univariate
        p =Plots.plot(size=(800, 500), xtickfont=font(15), ytickfont = font(15), legendfont = font(15), guidefont = font(15), legend =:topright)
        y_var = []
        LS = [:solid :dash]
        for i in 1:length(a0)
            y_var_tot = []

            for j in 1:length(Qm_vect)
                y_var = push!(y_var, f_pipe_construct_annualised(Qm_vect[j])[i])
            end


        end
        x_var = Qm_vect # Mt/yr
        # Plots.plot!(x_var, y_var./x_var, label = Labels[i], xlabel = "Mass flow MtCO2/yr", ylabel = "EUR/yr($(reference_year)/tCO2) for $(L) km")

        x_flat = Float64.(repeat(x_var,4))
        y_flat = Float64.(y_var) .* Scaling_ccts # !!ADJUSTMENT HERE
        Colors = ["springgreen4", "springgreen2", "lightseagreen", "darkseagreen1"]
        groupedbar!(x_flat, y_flat./x_flat, group = repeat(Labels, inner = length(Qm_vect)), color = repeat(Colors, inner = length(Qm_vect)), xlabel = L"Mass flow MtCO$_2$/yr", ylabel = "EUR/yr($(reference_year)/tCO2) for $(L) km", bar_position = :stack)

        x_var = Qm_vect # Mt/yr
        for p_nr in 1:2
            Regression_transport =  piecewise_error(Range_opt, p_nr, Samples, Intercept)
            # println("Transport Regression parameters:", Regression_transport)
            A_0_pc_transport = Regression_transport[!,"A_0"][1] * Scaling_ccts # !!ADJUSTMENT HERE
            A_1_pc_transport = Regression_transport[!,"A_1"][1] * Scaling_ccts # !!ADJUSTMENT HERE
            x_breakpoints = Regression_transport[!,"x_breakpoints"][1]
    

            y_value_linear = (A_0_pc_transport .+ A_1_pc_transport .* transpose(x_var)) ./ (1 + OandM_pipes)
            nrows = size(y_value_linear, 1)
            global y_masked = fill(0.0, length(x_var))
            for i in 1:nrows
                idx = (x_var .<= x_breakpoints[i+1]) .&  (x_breakpoints[i] .<= x_var)
                y_masked[idx] = y_value_linear[i, idx]
            end
            # y_var_linear = push!(y_var_linear, y_value_linear)
            Plots.plot!(x_var, y_masked*(1+OandM_pipes)./x_var, label = "$(p_nr)-piece fit", xlabel = "Mass flow MtCO2/yr", ylabel = "EUR($(reference_year))/tCO2 for $(L) km (annualised)", ls = LS[p_nr], color = "black", lw = 2,  xlim = [0, x_max], ylim=[0,0.10])
            # Plots.plot!(x_var, y_masked*OandM_pipes./x_var, label = "Total O&M", xlabel = L"Mass flow MtCO$_2$/yr", ylabel = "EUR($(reference_year))/tCO2 for $(L) km", ls = :dash, color = "grey", lw = 2, xlim=[0, x_max],legend = (0.55, 0.95))
        end

        Plots.plot!(twinx(p), xlabel = "", ylabel= "", yticks = false)

        Plots.scatter!(x_zep_MtCO2, y_zep_specific_annualised, label= "ZEP", markershape= :x, color = "black", markersize=4)
        Plots.scatter!(x_ippc_MtCO2, y_ipcc_specific_annualised, label= "IPCC", markershape= :^,color = "black", markersize=4)
        Plots.scatter!(x_JRC_MtCO2, y_JRC_specific_annualised, label= "JRC", markershape= :v,color = "black", markersize=4)
        Plots.scatter!(x_dea_MtCO2, y_dea_specific_annualised, label="DEA",  markershape= :o, color = "black", markersize=4, legend=:topright)
        # Plots.plot!([20, 20], [0, 1.5], label = false, ls=:dash, color = :black)
        Plots.plot!(twiny(p), xlabel = "Pipeline diameter [m]", ylabel= "", xlim = [0, D_max], ylim=[0,0.10], xtickfont=font(15), ytickfont = font(15), legendfont = font(15), guidefont = font(15))

           

        
        display(p)
        save_path = "./Figures/Pipe_cost_yr_EURptCO2pkm.svg"
        Plots.savefig(p, save_path)
        # ################################################################
        # # non annualised
        # f_pipe_construct_total(x) = A0_pipe_construct_total.*(((x.* 10^9 ./ (365*24*60*60))./(Velocity*pi*0.25*Density_2)).^0.5*Inch_per_meter).^(A2_pipe_construct)*L # univariate
        # p =Plots.plot(size=(800, 500), xtickfont=font(15), ytickfont = font(15), legendfont = font(15), guidefont = font(15))
        # y_var_linear = []
        # for i in 1:length(a0)
        #     y_var = []
        #     y_var_tot = []

        #     for j in 1:length(Qm_vect)
        #         y_var_tot = push!(y_var, f_pipe_construct_total(Qm_vect[j])[i])
        #     end
        #     x_var = Qm_vect # Mt/yr
        #     Plots.plot!(x_var, y_var_tot, label = Labels[i], xlabel = "Mass flow MtCO2/yr", ylabel = "MEUR/yr($(reference_year)) for $(L) km")
        # end

        # x_var = Qm_vect # Mt/yr
        # y_var_tot = [sum(f_pipe_construct_total(Qm_vect[j])[i]  for i in 1:length(a0)) for j in 1:length(Qm_vect)]
        # y_value_linear = (A_0_pc_transport .+ x_var.*A_1_pc_transport)./(1+OandM_pipes)
        # Plots.plot!(x_var, y_var_tot*(1+OandM_pipes), label = "Total construction (not annualised))", xlabel = "Mass flow MtCO2/yr", ylabel = "MEUR($(reference_year)) for $(L) km", ls = :solid, color = "black", lw = 2, xlim= [0, x_max])
        # # Plots.plot!(x_var, y_var*(1+OandM_pipes), label = "Total construction (annualised)", xlabel = "Mass flow MtCO2/yr", ylabel = "EUR/yr($(reference_year)) for $(L) km", ls = :solid, color = "black", lw = 2)
        # # Plots.plot!(x_var, y_var*OandM_pipes, label = "Total O&M", xlabel = "Mass flow MtCO2/yr", ylabel = "EUR/yr($(reference_year)) for $(L) km", ls = :dash, color = "grey", lw = 2)
        # # Plots.plot!(x_var, y_var_linear, label = "Linear regression fit", xlabel = "Mass flow MtCO2/yr", ylabel = "EUR/yr($(reference_year)) for $(L) km", lw=3, color = "pink")


        # Plots.plot!(twiny(p), xlabel = "Pipeline diameter [m]", ylabel= "", xlim = ([0, D_max]))
        # Plots.plot!(twinx(p), xlabel = "", ylabel= "", yticks = false)
        # # Plots.plot!([20, 20], [0, 1.5], label = false, ls=:dash, color = :black)


    else
    end


    return A0_pipe_construct, A2_pipe_construct
end



function tariff_cluster(model_1)
    variables_extract(model_1)
    Participating_clusters = Dict(n =>
        sum(
            try
                cc_emitter[e]
            catch
                0
            end
            for e in Cluster_emitters[n]
        ) for n in CLUSTERS
    )   
    Clusters_activated_dict = Dict(key => (value > 0 ? 1 : 0) for (key, value) in Participating_clusters)

    # Tariff_dict = Dict(key => (t_fixed + t_c[key])*Clusters_activated_dict[key] for (key, value) in Clusters_activated_dict)
    Tariff_dict = Dict(key => (t_fixed + t_c[Emitter_cluster[key]])*cc_emitter[key] for key in EMITTERS)
   
    
    Tariff_df = DataFrame(
    Emitter = collect(keys(Tariff_dict)),
    Tariff   = collect(values(Tariff_dict))
)
    filename_tariff = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_tariff_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    
    
    CSV.write(filename_tariff, Tariff_df)
   
   
    return Tariff_df
end

function cluster_refpoint_distance(system_data_file, CLUSTERS)

    # Reference point in the port of Rotterdam
    Reference_lat = 51.898693 # 54.785329 
    Reference_lon =  4.414102 #3.679677
    P_ref = (Reference_lat, Reference_lon)
    Cluster_distance = Dict(c => 0.0 for c in CLUSTERS)
    Clusters = DataFrame(XLSX.readtable(system_data_file, "Clusters"))
    for c in CLUSTERS
        P_centroid = (Clusters[Clusters[:,"Cluster"].== c,"Lat"][1], Clusters[Clusters[:,"Cluster"].== c,"Lon"][1])
        distance_NZ = haversine(P_ref, P_centroid, 6372.8)
        Cluster_distance[c] = distance_NZ
    end

return Cluster_distance
end