"""Patch para corrigir _calculate_balance_from_payments no mercadopago_connector.py"""
import sys

path = "/home/homelab/eddie-auto-dev/specialized_agents/banking/mercadopago_connector.py"
with open(path, "r") as f:
    content = f.read()

old_block = '''                for p in results:
                    status = p.get("status", "")
                    amt = Decimal(str(p.get("transaction_amount", 0)))
                    net = Decimal(str(p.get("net_received_amount", 0)))

                    if status == "approved":
                        if net > 0:
                            total_received += net
                        elif amt > 0 and net == 0:
                            total_sent += amt
                    elif status in ("pending", "in_process", "authorized"):
                        total_blocked += amt'''

new_block = '''                for p in results:
                    status = p.get("status", "")
                    amt = Decimal(str(p.get("transaction_amount", 0)))
                    td = p.get("transaction_details") or {}
                    net = Decimal(str(td.get("net_received_amount", 0) or 0))
                    op_type = p.get("operation_type", "")

                    if status == "approved":
                        # account_fund = fundos recebidos (PIX, TED, boleto)
                        if op_type == "account_fund":
                            total_received += net if net > 0 else amt
                        # money_transfer = transferência enviada
                        elif op_type == "money_transfer":
                            total_sent += amt
                        # regular_payment = pagamento/compra
                        elif op_type == "regular_payment":
                            total_sent += amt
                        # money_exchange, partition_transfer = internas (neutras)
                        elif op_type in ("money_exchange", "partition_transfer"):
                            pass
                        else:
                            # Outros: se net > 0 recebeu, senão enviou
                            if net > 0:
                                total_received += net
                            elif amt > 0:
                                total_sent += amt
                    elif status in ("pending", "in_process", "authorized"):
                        total_blocked += amt'''

if old_block in content:
    content = content.replace(old_block, new_block)
    with open(path, "w") as f:
        f.write(content)
    print("OK - balance calculation fixed")
else:
    print("ERROR - block not found")
    idx = content.find("for p in results:")
    if idx >= 0:
        snippet = content[idx:idx+600]
        print(snippet)
    sys.exit(1)
