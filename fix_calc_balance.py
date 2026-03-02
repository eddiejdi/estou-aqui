"""Fix _calculate_balance_from_payments: access net_received_amount from transaction_details + use operation_type"""
path = "/home/homelab/eddie-auto-dev/specialized_agents/banking/mercadopago_connector.py"
with open(path, "r") as f:
    content = f.read()

# Old broken block (net_received_amount at wrong level)
old = '''                for p in results:
                    status = p.get("status", "")
                    amt = Decimal(str(p.get("transaction_amount", 0)))
                    net = Decimal(str(p.get("net_received_amount", 0)))

                    if status == "approved":
                        if net > 0:
                            total_received += net
                        elif amt > 0 and net == 0:
                            total_sent += amt
                    elif status in ("pending", "in_process", "authorized"):
                        total_blocked += amt

                offset = paging.get("offset", 0) + paging.get("limit", 100)'''

new = '''                for p in results:
                    status = p.get("status", "")
                    amt = Decimal(str(p.get("transaction_amount", 0)))
                    td = p.get("transaction_details") or {}
                    net = Decimal(str(td.get("net_received_amount", 0) or 0))
                    op_type = p.get("operation_type", "")

                    if status == "approved":
                        if op_type == "account_fund":
                            total_received += net if net > 0 else amt
                        elif op_type in ("money_transfer", "regular_payment"):
                            total_sent += amt
                        elif op_type in ("money_exchange", "partition_transfer"):
                            pass  # internas, saldo liquido zero
                        else:
                            if net > 0:
                                total_received += net
                            elif amt > 0:
                                total_sent += amt
                    elif status in ("pending", "in_process", "authorized"):
                        total_blocked += amt

                offset = paging.get("offset", 0) + paging.get("limit", 100)'''

if old in content:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print("OK - _calculate_balance_from_payments fixed")
    print(f"File: {len(content.splitlines())} lines")
else:
    print("ERROR - old block not found")
    # Find nearest match
    idx = content.find("net = Decimal(str(p.get(")
    if idx >= 0:
        start = max(0, idx - 200)
        print(content[start:idx+400])
    else:
        print("net_received_amount reference not found at all")
