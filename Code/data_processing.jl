#
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


function merge_csv_files_to_excel(output_filename, file_list)
    # Create a new Excel file
    XLSX.openxlsx(output_filename, mode="rw") do xf
        for (i, file) in enumerate(file_list)
            SheetName = "$(Scenario_name_vect[i])_$(Region)_$(CO2_tax)"
            df_csv = CSV.read(file, DataFrame)
            try 
                XLSX.addsheet!(xf, SheetName)
            catch 
            end
            sheet = xf[SheetName]
            XLSX.writetable!(sheet, df_csv; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
        end
    end
end


function HPC_csv_output_data_to_excel(Scenario_name_vect, Region, CO2_tax, detail_level)
    file_list_industry = []
    file_list_pipelines = []
    file_list_stats = []
    for Scenario_name in Scenario_name_vect
        file_list_industry_int = ["./Output data files/CSV intermediaries $(detail_level)/"].* ["Results_industry_HPC_$(Scenario_name)_$(Region)_$(CO2_tax).csv"]
        file_list_pipelines_int = ["./Output data files/CSV intermediaries $(detail_level)/"].* ["Results_pipelines_HPC_$(Scenario_name)_$(Region)_$(CO2_tax).csv"]
        file_list_stats_int = ["./Output data files/CSV intermediaries $(detail_level)/"].* ["Results_statistics_HPC_$(Scenario_name)_$(Region)_$(CO2_tax).csv"]

        push!(file_list_industry, file_list_industry_int)
        push!(file_list_pipelines, file_list_pipelines_int)
        push!(file_list_stats, file_list_stats_int)
    end 

    merge_csv_files_to_excel("./Output data files/Results_industry_$(Region)_HPC.xlsx", file_list_industry)
    merge_csv_files_to_excel("./Output data files/Results_pipelines_$(Region)_HPC.xlsx", file_list_pipelines)
    merge_csv_files_to_excel("./Output data files/Results_statistics_$(Region)_HPC.xlsx", file_list_stats)
end


function HPC_csv_input_data_to_excel(Scenario_name_vect, Region, CO2_tax, detail_level)
    file_list_industry = []
    file_list_pipelines = []
    file_list_stats = []
    for Scenario_name in Scenario_name_vect
        file_list_industry_int = ["./Output data files/CSV intermediaries $(detail_level)/$(Region)/$(CO2_tax)/"].* ["Results_industry_HPC_$(Scenario_name)_$(Region)_$(CO2_tax).csv"]
        file_list_pipelines_int = ["./Output data files/CSV intermediaries $(detail_level)/"].* ["Results_pipelines_HPC_$(Scenario_name)_$(Region)_$(CO2_tax).csv"]
        file_list_stats_int = ["./Output data files/CSV intermediaries $(detail_level)/"].* ["Results_statistics_HPC_$(Scenario_name)_$(Region)_$(CO2_tax).csv"]

        push!(file_list_industry, file_list_industry_int)
        push!(file_list_pipelines, file_list_pipelines_int)
        push!(file_list_stats, file_list_stats_int)
    end 

    merge_csv_files_to_excel("./Output data files/Results_industry_$(Region)_HPC.xlsx", file_list_industry)
    merge_csv_files_to_excel("./Output data files/Results_pipelines_$(Region)_HPC.xlsx", file_list_pipelines)
    merge_csv_files_to_excel("./Output data files/Results_statistics_$(Region)_HPC.xlsx", file_list_stats)
end



function extracting_start_solution(model_1, Scenario_name, detail_level, Pieces)

    delta_matrix = [value(model_1[:delta][pc, p]) for p in PIPES, pc in 1:Pieces]  # note: transpose order
    beta_off_vector = [value(model_1[:beta_off][s]) for s in STORAGES_OFF]  # note: transpose order
    beta_inl_vector = [value(model_1[:beta_inl][s]) for s in STORAGES_INL]  # note: transpose order

    beta_off_padded = vcat(beta_off_vector, fill(missing, length(delta_matrix[:,1]) - length(beta_off_vector)))
    beta_inl_padded  = vcat(beta_inl_vector,  fill(missing, length(delta_matrix[:,1]) - length(beta_inl_vector)))
    delta_df = DataFrame(delta_matrix, Symbol.(PIECES))
    beta_df = DataFrame(Symbol.("Storage_off") => beta_off_padded, 
    Symbol.("Storage_inl") => beta_inl_padded) 
    # rename!(delta_df, Dict(col => Symbol("Piece_", col) for col in names(delta_df)))
    data_binaries = hcat(delta_df, beta_df)
    filename_delta ="./Input data files/CSV hot start $(detail_level)/$(Region)_$(Scenario_name)_$(Pieces).csv"
    CSV.write(filename_delta, data_binaries)

    x1 = all_variables(model_1);
    x1_solution = value.(x1);

    d = Dict(string(n)=>v for (n,v) in zip(x1, x1_solution))
    filename_all_variables ="./Input data files/CSV hot start $(detail_level)/Dict_$(Region)_$(Scenario_name)_$(Pieces).csv"
    CSV.write(filename_all_variables, d)


end

function CCTS_element_selection(Region::String)
    if Region == "Trilateral"
        Pipeline_NUTS0 = ["BE", "NL", "DE", "FR", "LU", "NO", "SE", "DK"]
        #Pipeline_NUTS0 = ["BE", "NL", "DE", "FR"]
        NUTS_0 = ["BE" "NL"]   #  NUTS_0 = ["BE"] #
        NUTS_2 = ["DEA"] # ["DEA"] # PROBLEM: 2 dots are connected to south region, not to north... gives problem "DEA" NUTS_2 = []
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




function enya_hans_check(file)

    Hydrogen_results_file = "./Enya-Hans/hydrogen_backbone.xlsx"
    Hydrogen_df = DataFrame(XLSX.readtable(Hydrogen_results_file, "All_Combined_Data"))
    Hydrogen_df_BE = Hydrogen_df[(Hydrogen_df[:, "country"] .== "BE") .& (Hydrogen_df[:, "period"] .== Scenario_horizon) .&  (Hydrogen_df[:, "demand_scenario"] .== "min totex") .& (Hydrogen_df[:, "supply_scenario"] .== "offshore green h2"),:]
    Enya_Hans_filtered_df = unique(Hydrogen_df_BE, [:aidres_site_id, Symbol("totex_costs_per_kt_[meur/kt/y]")])


    Emitters = import_data_emitters(system_data_file::Any, Scenario_name::String, Scenario_horizon::Int64, project_run::Bool)
    Flore_filtered_df = Emitters[Emitters[:,"NUTS0"].== "BE", :]


    # Capture amounts
    sum(Enya_Hans_filtered_df[:, "captured_co2_[tco2/t]"]) #tCO2/t product per year
    sum(Flore_filtered_df[:, "Captured_CO2_1_tCO2ptpa"])   #tCO2/t product per year
    sum(Flore_filtered_df[:, "Captured_CO2_1_tCO2ptpa"].*(Flore_filtered_df[:, "Product_cap_ktpa"]./1000)) # MtCO2 per year

    # Calculating total capture amount of emitters and sort it 
    Flore_filtered_df.TOTAL_capture_MtCO2pa = Flore_filtered_df.Product_cap_ktpa .* Flore_filtered_df.Captured_CO2_1_tCO2ptpa/1000
    Flore_filtered_df.TOTAL_BIO_capture_MtCO2pa = Flore_filtered_df.Product_cap_ktpa .* Flore_filtered_df.Capture_ofwhich_bio_1_tCO2ptpa/1000
    Flore_filtered_df.TOTAL_FOSSIL_capture_MtCO2pa =      Flore_filtered_df.TOTAL_capture_MtCO2pa -   Flore_filtered_df.TOTAL_BIO_capture_MtCO2pa
    Flore_filtered_df_sorted = sort(Flore_filtered_df, :TOTAL_capture_MtCO2pa, rev=true)
    Flore_combined_df = select(Flore_filtered_df_sorted, [:AidRES_site_id, :Sector_name, :Product_route_name, :Route_name1, :Product_cap_ktpa,  :Captured_CO2_1_tCO2ptpa, :TOTAL_capture_MtCO2pa, :TOTAL_BIO_capture_MtCO2pa, :TOTAL_FOSSIL_capture_MtCO2pa])


    column_labels_capture = DataFrame(Symbol("Total Capture MtCO2pa") => sum(Flore_filtered_df.TOTAL_capture_MtCO2pa), 
    Symbol("Total Fossil Capture MtCO2pa") =>  sum(Flore_filtered_df.TOTAL_FOSSIL_capture_MtCO2pa), Symbol("Total Bio Capture MtCO2pa") =>  sum(Flore_filtered_df.TOTAL_BIO_capture_MtCO2pa)
    )



    Flore_filtered_df_pr = filter!(row -> !occursin("chemical-PE", row.Product_route_name), deepcopy(Flore_filtered_df))
    sum(Flore_filtered_df[:, "Captured_CO2_1_tCO2ptpa"].*(Flore_filtered_df[:, "Product_cap_ktpa"]./1000)) # MtCO2 per year

    valid_site_ids = Set(Enya_Hans_filtered_df.aidres_site_id)
    Flore_eh_filtered_df = filter!(row -> !(row.AidRES_site_id in valid_site_ids), deepcopy(Flore_filtered_df)) # ok = only secondary steel 
    # Total Amount of fabricants 
    SECTOR_ID_E = [1 2 3 4 5 6]
    column_labels = ["EH", "F"]
    df_sector_count = DataFrame([Vector{Union{Missing, Any}}(undef, 6) for _ in column_labels], column_labels)
    for i in SECTOR_ID_E
        df_sector_count[i, "EH"] =  nrow(Enya_Hans_filtered_df[Enya_Hans_filtered_df[:,"aidres_sector"] .== i, :])
        df_sector_count[i, "F"] =  nrow(Flore_filtered_df[Flore_filtered_df[:,"Sector_id"] .== i, :])
    end
    # no steel secondary in EH 
    # 

    return 
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

    Qm_vect = 0:2.5:300 #Mton

    L =1   #km
    # f_transport(q) = (1+OandM_pipes).*sum(A0_pipe_construct.*(((q.* 10^9 ./ (365*24*60*60))./(Velocity*pi*0.25*Density_2)).^0.5*Inch_per_meter).^(A2_pipe_construct)) #MEUR
    x_max = 80
    D_max = mass_flow_to_diameter(x_max)
    if Plotting == true
        ################################################################
        # Annualised (per km)
        f_pipe_construct_annualised(x) = A0_pipe_construct.*(((x.* 10^9 ./ (365*24*60*60))./(Velocity*pi*0.25*Density_2)).^0.5*Inch_per_meter).^(A2_pipe_construct)*L # !!ADJUSTMENT HERE # univariate

        Regression_transport =  piecewise_error(Range_opt, Pieces, Samples, Intercept)
        # println("Transport Regression parameters:", Regression_transport)
        A_0_pc_transport = Regression_transport[!,"A_0"][1] * Scaling_ccts # !!ADJUSTMENT HERE
        A_1_pc_transport = Regression_transport[!,"A_1"][1] * Scaling_ccts # !!ADJUSTMENT HERE

        p =Plots.plot(size=(800, 500), xtickfont=font(15), ytickfont = font(15), legendfont = font(15), guidefont = font(15))
        y_var_linear = []
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
        groupedbar!(x_flat, y_flat, group = repeat(Labels, inner = length(Qm_vect)), color = repeat(Colors, inner = length(Qm_vect)), xlabel = L"Mass flow MtCO$_2$/yr", ylabel = "MEUR/yr($(reference_year)) for $(L) km", bar_position = :stack, legend= (0.1, 0.95))

        x_var = Qm_vect # Mt/yr

        y_var = [sum(f_pipe_construct_annualised(Qm_vect[j])[i]  for i in 1:length(a0)) for j in 1:length(Qm_vect)] .* Scaling_ccts # !!ADJUSTMENT HERE
        y_value_linear = (A_0_pc_transport .+ x_var.*A_1_pc_transport)./(1+OandM_pipes)
        y_var_linear = push!(y_var_linear, y_value_linear)
        # Plots.bar!(x_var, y_var*(1+OandM_pipes), label = "Total construction (annualised)", xlabel = "Mass flow MtCO2/yr", ylabel = "MEUR/yr($(reference_year)) for $(L) km", ls = :solid, color = "black", lw = 2)
        # Plots.bar!(x_var, y_var*OandM_pipes, label = "Total O&M", xlabel = "Mass flow MtCO2/yr", ylabel = "MEUR/yr($(reference_year)) for $(L) km", ls = :dash, color = "grey", lw = 2)
        Plots.plot!(x_var, y_var_linear, label = "Linear regression fit", xlabel = "Mass flow MtCO2/yr", ylabel = "MEUR($(reference_year))/yr for $(L) km", lw=2, color = "black", xlim = [0, x_max])



        Plots.plot!(twiny(p), xlabel = "Pipeline diameter [m]", ylabel= "", xlim = ([0, D_max]), xtickfont=font(15), ytickfont = font(15), legendfont = font(15), guidefont = font(15))
        Plots.plot!(twinx(p), xlabel = "", ylabel= "", yticks = false)
        # Plots.plot!([20, 20], [0, 1.5], label = false, ls=:dash, color = :black)
        

        
        display(p)
        save_path = "./Figures/Pipe_cost_yr_MEURpkm.svg"
        Plots.savefig(p, save_path)
        ################################################################
        # Levelised costs for certain length L en certain mass flow 
        f_pipe_construct_annualised(x) = A0_pipe_construct.*(((x.* 10^9 ./ (365*24*60*60))./(Velocity*pi*0.25*Density_2)).^0.5*Inch_per_meter).^(A2_pipe_construct)*L # univariate

        Regression_transport =  piecewise_error(Range_opt, Pieces, Samples, Intercept)
        # println("Transport Regression parameters:", Regression_transport)
        A_0_pc_transport = Regression_transport[!,"A_0"][1]
        A_1_pc_transport = Regression_transport[!,"A_1"][1]

        p =Plots.plot(size=(800, 500), xtickfont=font(15), ytickfont = font(15), legendfont = font(15), guidefont = font(15))
        y_var_linear = []
        y_var = []
        for i in 1:length(a0)
            y_var_tot = []

            for j in 1:length(Qm_vect)
                y_var = push!(y_var, f_pipe_construct_annualised(Qm_vect[j])[i])
            end
            x_var = Qm_vect # Mt/yr

        end
        # Plots.plot!(x_var, y_var./x_var, label = Labels[i], xlabel = "Mass flow MtCO2/yr", ylabel = "EUR/yr($(reference_year)/tCO2) for $(L) km")

        x_flat = Float64.(repeat(x_var,4))
        y_flat = Float64.(y_var) .* Scaling_ccts # !!ADJUSTMENT HERE
        Colors = ["springgreen4", "springgreen2", "lightseagreen", "darkseagreen1"]
        groupedbar!(x_flat, y_flat./x_flat, group = repeat(Labels, inner = length(Qm_vect)), color = repeat(Colors, inner = length(Qm_vect)), xlabel = L"Mass flow MtCO$_2$/yr", ylabel = "EUR/yr($(reference_year)/tCO2) for $(L) km", bar_position = :stack, legend= (0.1, 0.95))

        x_var = Qm_vect # Mt/yr
        y_var = [sum(f_pipe_construct_annualised(Qm_vect[j])[i]  for i in 1:length(a0)) for j in 1:length(Qm_vect)] .* Scaling_ccts # !!ADJUSTMENT HERE
        y_value_linear = (A_0_pc_transport .+ x_var.*A_1_pc_transport)./(1+OandM_pipes)
        y_var_linear = push!(y_var_linear, y_value_linear)
        Plots.plot!(x_var, y_var*(1+OandM_pipes)./x_var, label = "Total construction (annualised)", xlabel = "Mass flow MtCO2/yr", ylabel = "EUR($(reference_year))/tCO2 for $(L) km", ls = :solid, color = "black", lw = 2)
        Plots.plot!(x_var, y_var*OandM_pipes./x_var, label = "Total O&M", xlabel = L"Mass flow MtCO$_2$/yr", ylabel = "EUR($(reference_year))/tCO2 for $(L) km", ls = :dash, color = "grey", lw = 2, xlim=[0, x_max],legend = (0.55, 0.95))


        Plots.plot!(twiny(p), xlabel = "Pipeline diameter [m]", ylabel= "", xlim = [0, D_max], xtickfont=font(15), ytickfont = font(15), legendfont = font(15), guidefont = font(15))
        Plots.plot!(twinx(p), xlabel = "", ylabel= "", yticks = false)
        # Plots.plot!([20, 20], [0, 1.5], label = false, ls=:dash, color = :black)

           

        
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
    Tariff_cluster = Dict(key => t_c[key]*Clusters_activated_dict[key] for (key, value) in Clusters_activated_dict)
    return Tariff_cluster
end